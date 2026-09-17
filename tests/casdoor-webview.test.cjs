// Run: node --test tests/casdoor-webview.test.cjs
// Execute the production QML's JavaScript with deterministic native-navigation events.
// This covers state transitions, not WKWebView painting or Qt signal delivery.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const qml = fs.readFileSync(path.join(__dirname, '../qml/Auth/CasdoorWebView.qml'), 'utf8');
const callbackUrl = 'https://app.example/callback?code=test-code&state=test-state';

function createLogin() {
    const root = {
        visible: true,
        webContentSuppressed: false,
        pageContentReady: false,
        codeAlreadyReceived: false,
        hideWebContentDuringHandover: false,
        isLoginFlowActive: true,
        hasNotifiedReady: false,
        hasNotifiedRedirecting: false,
        pendingCode: '',
        pendingState: '',
        pendingHandover: false,
        pendingHandoverCode: '',
        pendingHandoverState: '',
        blockedHandoverCode: '',
        expectedRedirectUri: 'https://app.example/callback',
        expectedStateValue: 'test-state',
        lastNonBlankUrl: '',
        backendReportsHttpErrors: false,
        retryCount: 0,
        maxRetries: 2,
        readySignals: 0,
        codes: [],
        errors: [],
        pageReadyToShow() { this.readySignals++; },
        authCodeReceived(code, state) { this.codes.push({ code, state }); },
        oauthRedirecting() {},
        loadError(message) { this.errors.push(message); },
    };
    root.root = root;
    root.CasdoorHelper = { getEndpoint: () => 'https://sso.example' };
    root.WebView = { LoadStartedStatus: 0, LoadSucceededStatus: 2, LoadFailedStatus: 3 };
    for (const name of ['codeExtractionTimer', 'deferredHandoverTimer', 'retryLoginTimer', 'startLoginTimer']) {
        root[name] = {
            running: false,
            stop() { this.running = false; },
            restart() { this.running = true; },
        };
    }
    root.webView = { url: 'https://sso.example/login', loading: false, loadProgress: 0, stop() {} };
    const context = vm.createContext(root);
    for (const match of qml.matchAll(/^    function (\w+)\(([^)]*)\) \{([\s\S]*?)^    \}/gm)) {
        root[match[1]] = vm.runInContext(`(function(${match[2]}) {${match[3]}})`, context);
    }
    const visibility = qml.match(/readonly property bool webContentOnScreen: (.*)/)[1];
    Object.defineProperty(root, 'webContentOnScreen', { get: () => vm.runInContext(visibility, context) });
    const loading = qml.match(/^        onLoadingChanged: function \(loadRequest\) \{([\s\S]*?)^        \}/m)[1];
    const progress = qml.match(/^        onLoadProgressChanged: \{([\s\S]*?)^        \}/m)[1];
    const navigation = qml.match(/^        onUrlChanged: \{([\s\S]*?)^        \}/m)[1];
    const handover = qml.match(/id: deferredHandoverTimer[\s\S]*?onTriggered: \{([\s\S]*?)^        \}/m)[1];
    const onLoading = vm.runInContext(`(function(loadRequest) {${loading}})`, context);
    root.load = status => onLoading({ status: root.WebView[status], errorString: 'test failure' });
    root.progress = value => {
        root.webView.loadProgress = value;
        vm.runInContext(progress, context);
    };
    root.navigate = url => {
        root.webView.url = url;
        root.url = url;
        vm.runInContext(`(function() {${navigation}})()`, context);
    };
    root.handover = () => vm.runInContext(`(function() {${handover}})()`, context);
    return root;
}

test('successful login page appears and notifies host even without intermediate progress', () => {
    const login = createLogin();
    assert.equal(login.webContentOnScreen, false);
    login.load('LoadSucceededStatus');
    assert.equal(login.webContentOnScreen, true);
    assert.equal(login.readySignals, 1);
    login.progress(100);
    login.load('LoadSucceededStatus');
    assert.equal(login.readySignals, 1);
});

test('blank and non-HTTP completion cannot reveal the native view', () => {
    for (const url of ['', 'about:blank', 'file:///tmp/login.html']) {
        const login = createLogin();
        login.navigate(url);
        login.progress(100);
        login.load('LoadSucceededStatus');
        assert.equal(login.webContentOnScreen, false, url);
        assert.equal(login.readySignals, 0, url);
    }
});

test('macOS callback blank stays hidden through deferred handover and native exchange', () => {
    const login = createLogin();
    login.progress(50);
    login.navigate(callbackUrl);
    login.load('LoadSucceededStatus');
    assert.equal(login.webView.url, 'about:blank');
    assert.equal(login.webContentOnScreen, false);
    login.load('LoadSucceededStatus');
    login.handover();
    assert.deepEqual(login.codes, [{ code: 'test-code', state: 'test-state' }]);
    assert.equal(login.hideWebContentDuringHandover, false);
    assert.equal(login.webContentOnScreen, false);
    login.load('LoadSucceededStatus');
    assert.equal(login.webContentOnScreen, false);
    login.handover();
    assert.equal(login.codes.length, 1);
});

test('retry clears old readiness before navigating to a blank page', () => {
    const login = createLogin();
    login.progress(50);
    let url = login.webView.url;
    Object.defineProperty(login.webView, 'url', {
        get: () => url,
        set: value => {
            assert.equal(login.webContentOnScreen, false, 'old page must be hidden before URL clear');
            url = value;
        },
    });
    login.load('LoadFailedStatus');
    assert.equal(login.retryCount, 1);
    assert.equal(login.retryLoginTimer.running, true);
    login.load('LoadSucceededStatus');
    assert.equal(login.webContentOnScreen, false);
});

test('phone-binding page on HTTP-error-reporting backends remains available', () => {
    const login = createLogin();
    login.backendReportsHttpErrors = true;
    login.navigate(callbackUrl);
    login.load('LoadSucceededStatus');
    assert.equal(login.webContentOnScreen, true);
    assert.equal(login.deferredHandoverTimer.running, false);
    assert.equal(login.codes.length, 0);
});

test('native binding-required recovery can show the previous web flow again', () => {
    const login = createLogin();
    login.progress(50);
    login.navigate(callbackUrl);
    login.load('LoadSucceededStatus');
    login.handover();
    login.resumeWebFlowAfterNativeLoginFailed();
    assert.equal(login.codeAlreadyReceived, false);
    assert.equal(login.isLoginFlowActive, true);
    assert.equal(login.webView.url, callbackUrl);
    assert.equal(login.webContentOnScreen, true);
});
