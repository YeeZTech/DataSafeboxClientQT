import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine

Rectangle {
    id: root
    color: "#f5f8fb"
    
    signal authCodeReceived(string code, string state)
    signal loadError(string errorMsg)
    signal pageReadyToShow()
    signal oauthRedirecting()
    
    property alias url: webView.url
    property bool isLoading: webView.loading
    // Whether the login page has rendered enough to be visible
    property bool pageContentReady: false
    property bool codeAlreadyReceived: false
    property string pendingCode: ""
    property string pendingState: ""
    property bool hasNotifiedReady: false
    property bool hasNotifiedRedirecting: false
    property bool isLoginFlowActive: false
    property bool pendingHandover: false
    property string pendingHandoverCode: ""
    property string pendingHandoverState: ""
    property string blockedHandoverCode: ""
    property bool hideWebContentDuringHandover: false
    property int retryCount: 0
    property string expectedRedirectUri: ""
    property string expectedStateValue: ""
    property string lastNonBlankUrl: ""
    readonly property int maxRetries: 2
    readonly property int deferredHandoverProbeMs: 1200
    readonly property bool canGoBack: webView && webView.canGoBack
    property bool isQrCodePage: false
    
    function goBack() {
        if (webView && webView.canGoBack) {
            webView.goBack()
        }
    }
    
    Timer {
        id: codeExtractionTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!root.codeAlreadyReceived && root.pendingCode !== "" && !webView.loading) {
                root.codeAlreadyReceived = true
                root.isLoginFlowActive = false
                webView.stop()
                webView.url = ""
                root.authCodeReceived(root.pendingCode, root.pendingState)
                root.pendingCode = ""
                root.pendingState = ""
                root.pendingHandover = false
                root.pendingHandoverCode = ""
                root.pendingHandoverState = ""
            } else if (webView.loading) {
                codeExtractionTimer.restart()
            }
        }
    }
    
    function startLogin() {
        startLoginTimer.stop()
        retryLoginTimer.stop()
        codeExtractionTimer.stop()
        codeAlreadyReceived = false
        pendingCode = ""
        pendingState = ""
        hasNotifiedReady = false
        hasNotifiedRedirecting = false
        isLoginFlowActive = false
        hideWebContentDuringHandover = false
        deferredHandoverTimer.stop()
        pendingHandover = false
        pendingHandoverCode = ""
        pendingHandoverState = ""
        blockedHandoverCode = ""
        hideWebContentDuringHandover = false
        retryCount = 0
        pageContentReady = false
        expectedRedirectUri = (CasdoorHelper.getRedirectUri ? CasdoorHelper.getRedirectUri() : "")
        expectedStateValue = ""
        lastNonBlankUrl = ""
        webView.stop()
        webView.url = ""
        startLoginTimer.restart()
    }
    
    function clearState() {
        startLoginTimer.stop()
        retryLoginTimer.stop()
        codeExtractionTimer.stop()
        codeAlreadyReceived = false
        pendingCode = ""
        pendingState = ""
        hasNotifiedReady = false
        hasNotifiedRedirecting = false
        isLoginFlowActive = false
        hideWebContentDuringHandover = false
        pendingHandover = false
        pendingHandoverCode = ""
        pendingHandoverState = ""
        blockedHandoverCode = ""
        retryCount = 0
        pageContentReady = false
        expectedRedirectUri = ""
        expectedStateValue = ""
        lastNonBlankUrl = ""
        webView.stop()
        webView.url = ""
        // Cookie cleanup is now handled by CasdoorHelper.logout() → performLocalCleanup()
        // after the server-side logout request completes. Do NOT delete cookies here,
        // because the C++ side needs casdoor_session_id to call POST /api/logout.
    }

    function extractAuthCode(urlStr) {
        if (!urlStr || urlStr.length === 0) {
            return ""
        }
        var codeMatch = urlStr.match(/[?&]code=([^&#]+)/)
        if ((!codeMatch || !codeMatch[1]) && urlStr.indexOf("#") !== -1) {
            var fragment = urlStr.substring(urlStr.indexOf("#") + 1)
            codeMatch = fragment.match(/(?:^|[?&])code=([^&#]+)/)
        }
        if (!codeMatch || !codeMatch[1]) {
            return ""
        }
        return decodeURIComponent(codeMatch[1]).trim()
    }

    function extractState(urlStr) {
        if (!urlStr || urlStr.length === 0) {
            return ""
        }
        var stateMatch = urlStr.match(/[?&]state=([^&#]+)/)
        if ((!stateMatch || !stateMatch[1]) && urlStr.indexOf("#") !== -1) {
            var fragment = urlStr.substring(urlStr.indexOf("#") + 1)
            stateMatch = fragment.match(/(?:^|[?&])state=([^&#]+)/)
        }
        if (!stateMatch || !stateMatch[1]) {
            return ""
        }
        return decodeURIComponent(stateMatch[1]).trim()
    }

    function normalizeCallbackUrl(urlStr) {
        if (!urlStr || urlStr.length === 0) {
            return ""
        }
        var normalized = urlStr
        var queryPos = normalized.indexOf("?")
        if (queryPos >= 0) {
            normalized = normalized.substring(0, queryPos)
        }
        var hashPos = normalized.indexOf("#")
        if (hashPos >= 0) {
            normalized = normalized.substring(0, hashPos)
        }
        while (normalized.length > 0 && normalized.charAt(normalized.length - 1) === "/") {
            normalized = normalized.substring(0, normalized.length - 1)
        }
        return normalized
    }

    function isExpectedCallbackUrl(urlStr) {
        if (!urlStr || urlStr.length === 0) {
            return false
        }
        var currentUrl = normalizeCallbackUrl(urlStr)
        var redirectUrl = normalizeCallbackUrl(expectedRedirectUri)
        if (redirectUrl.length === 0) {
            return false
        }
        // Normal callback: https://.../callback/?code=...&state=...
        if (currentUrl === redirectUrl) {
            return true
        }
        // Provider-specific callback variant:
        // https://.../callback/<state>?code=...&state=<provider_state>
        if (currentUrl.indexOf(redirectUrl + "/") === 0) {
            return true
        }
        return false
    }

    function extractCallbackStateFromPath(urlStr) {
        if (!urlStr || urlStr.length === 0) {
            return ""
        }
        var redirectUrl = normalizeCallbackUrl(expectedRedirectUri)
        var currentUrl = normalizeCallbackUrl(urlStr)
        if (redirectUrl.length === 0) {
            return ""
        }
        var prefix = redirectUrl + "/"
        if (currentUrl.indexOf(prefix) !== 0) {
            return ""
        }
        var pathState = currentUrl.substring(prefix.length)
        return decodeURIComponent(pathState).trim()
    }

    function isSsoCallbackUrl(urlStr) {
        if (!urlStr || urlStr.length === 0) {
            return false
        }
        var ssoCallbackUrl = CasdoorHelper.getEndpoint() + "/callback"
        return ssoCallbackUrl.length > 0 && urlStr.indexOf(ssoCallbackUrl) === 0
    }

    function isCallbackPathUrl(urlStr) {
        return extractStateFromCallbackPath(urlStr).length > 0
    }

    function extractStateFromCallbackPath(urlStr) {
        if (!urlStr || urlStr.length === 0) {
            return ""
        }
        var redirectBase = normalizeCallbackUrl(expectedRedirectUri)
        if (!redirectBase || redirectBase.length === 0) {
            return ""
        }
        var noQuery = urlStr
        var qPos = noQuery.indexOf("?")
        if (qPos >= 0) {
            noQuery = noQuery.substring(0, qPos)
        }
        var hPos = noQuery.indexOf("#")
        if (hPos >= 0) {
            noQuery = noQuery.substring(0, hPos)
        }
        while (noQuery.length > 0 && noQuery.charAt(noQuery.length - 1) === "/") {
            noQuery = noQuery.substring(0, noQuery.length - 1)
        }

        var prefix = redirectBase + "/"
        if (noQuery.indexOf(prefix) !== 0) {
            return ""
        }
        var suffix = noQuery.substring(prefix.length)
        if (!suffix || suffix.length === 0) {
            return ""
        }
        var slashPos = suffix.indexOf("/")
        if (slashPos >= 0) {
            suffix = suffix.substring(0, slashPos)
        }
        return decodeURIComponent(suffix).trim()
    }

    function finishLoginWithCode(code, state, reason) {
        if (!code || code.length === 0 || root.codeAlreadyReceived) {
            return
        }
        root.codeAlreadyReceived = true
        root.isLoginFlowActive = false
        codeExtractionTimer.stop()
        deferredHandoverTimer.stop()
        root.authCodeReceived(code, state)
        root.pendingCode = ""
        root.pendingState = ""
        root.pendingHandover = false
        root.pendingHandoverCode = ""
        root.pendingHandoverState = ""
        root.blockedHandoverCode = ""
        root.hideWebContentDuringHandover = false
    }

    // If native token exchange fails with "bind phone first", allow WebView
    // to continue server-side binding flow without restarting from login page.
    function resumeWebFlowAfterNativeLoginFailed() {
        codeAlreadyReceived = false
        isLoginFlowActive = true
        hideWebContentDuringHandover = false
        pendingCode = ""
        pendingState = ""
        pendingHandover = false
        pendingHandoverCode = ""
        pendingHandoverState = ""
        blockedHandoverCode = ""
        codeExtractionTimer.stop()
        deferredHandoverTimer.stop()
        var currentUrl = webView.url ? webView.url.toString() : ""
        if (currentUrl === "about:blank" && lastNonBlankUrl.length > 0) {
            webView.url = lastNonBlankUrl
        }
    }
    
    Timer {
        id: startLoginTimer
        interval: 300
        repeat: false
        onTriggered: {
            // Always clear in-memory cookies right before navigation so Casdoor
            // never sees a stale session and shows "使用以下账号继续".
            if (casdoorProfile && casdoorProfile.cookieStore) {
                casdoorProfile.cookieStore.deleteAllCookies()
            }
            var signinUrl = CasdoorHelper.getSigninUrl()
            expectedStateValue = (CasdoorHelper.getStateValue ? CasdoorHelper.getStateValue() : "")
            isLoginFlowActive = true
            webView.url = signinUrl
        }
    }

    // Retry timer: waits longer before retrying after a transient load failure
    Timer {
        id: retryLoginTimer
        interval: 1000
        repeat: false
        onTriggered: {
            var signinUrl = CasdoorHelper.getSigninUrl()
            expectedStateValue = (CasdoorHelper.getStateValue ? CasdoorHelper.getStateValue() : "")
            isLoginFlowActive = true
            webView.url = signinUrl
        }
    }

    // After final callback appears, defer handover briefly so web-side phone-binding
    // page has a chance to render if server requires it.
    Timer {
        id: deferredHandoverTimer
        interval: deferredHandoverProbeMs
        repeat: false
        onTriggered: {
            if (root.codeAlreadyReceived || !root.pendingHandover) {
                return
            }

            var currentUrl = webView.url ? webView.url.toString() : ""
            var expectedUrl = root.isExpectedCallbackUrl(currentUrl)
            var blankAfterCallback = currentUrl === "about:blank" && root.pendingHandoverCode.length > 0

            // Only hand over when we are still on the final callback page,
            // or when callback 404 has been intentionally blanked out.
            if (expectedUrl || blankAfterCallback) {
                var handoverCode = root.pendingHandoverCode
                var handoverState = root.pendingHandoverState
                var expectedState = (root.expectedStateValue || "").trim()
                if (expectedState.length > 0) {
                    handoverState = expectedState
                }
                if (handoverCode.length > 0 && handoverCode !== root.blockedHandoverCode) {
                    root.pendingCode = handoverCode
                    root.pendingState = handoverState
                    root.finishLoginWithCode(handoverCode, handoverState, "deferred-callback-handover")
                }
            }
        }
    }
    
    WebEngineView {
        id: webView
        anchors.fill: parent
        anchors.margins: 0
        visible: !root.hideWebContentDuringHandover && root.pageContentReady

        settings.showScrollBars: false

        Component.onCompleted: {
            webView.settings.showScrollBars = false
        }
        
        onLoadingChanged: function(loadRequest) {
            var currentUrl = webView.url ? webView.url.toString() : ""
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                // If the callback URL served actual content (e.g. phone binding page),
                // stop the deferred handover timer so the user can interact with the page.
                // When the user finishes binding, Casdoor will issue a fresh redirect
                // that onNavigationRequested / onUrlChanged will capture normally.
                if (root.isExpectedCallbackUrl(currentUrl) && root.pendingHandover) {
                    deferredHandoverTimer.stop()
                    codeExtractionTimer.stop()
                    root.hideWebContentDuringHandover = false
                    root.pageContentReady = true
                    return
                }
                if (root.pendingCode !== "" && !root.codeAlreadyReceived) {
                    codeExtractionTimer.restart()
                }
            } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                // Callback pages may intentionally return 404 while still carrying valid OAuth code/state.
                // Hide the 404 page immediately and continue deferred native handover.
                var isExpectedCallbackFailure = root.isExpectedCallbackUrl(currentUrl)
                if (isExpectedCallbackFailure) {
                    root.hideWebContentDuringHandover = true
                    webView.stop()
                    webView.url = "about:blank"
                    deferredHandoverTimer.restart()
                    return
                }

                // Only handle errors when actively in a login flow.
                // Ignore errors from URL clears (url="") or aborted navigations.
                if (root.isLoginFlowActive) {
                    root.isLoginFlowActive = false
                    if (root.retryCount < root.maxRetries) {
                        // Automatically retry after a short delay
                        root.retryCount++
                        webView.stop()
                        webView.url = ""
                        retryLoginTimer.restart()
                    } else {
                        root.loadError(loadRequest.errorString)
                    }
                }
            } else if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                root.hasNotifiedReady = false
            }
        }

        onCertificateError: function(error) {
            // 仅在测试环境忽略自签名/无效证书；正式环境必须拒绝以防中间人攻击
            if (typeof AppConfig !== "undefined" && AppConfig.isTestEnv && AppConfig.isTestEnv()) {
                error.ignoreCertificateError()
            } else {
                error.rejectCertificate()
            }
        }
        
        onLoadProgressChanged: {
            var urlStr = webView.url.toString()
            if (root.isLoginFlowActive && !root.hasNotifiedReady && webView.loadProgress >= 30 && urlStr.length > 0 && urlStr.indexOf("http") === 0) {
                root.hasNotifiedReady = true
                root.pageContentReady = true
                root.pageReadyToShow()
            }
        }
        
        onNavigationRequested: function(request) {
            if (root.codeAlreadyReceived) {
                return
            }

            var targetUrl = request.url ? request.url.toString() : ""
            var isExpected = root.isExpectedCallbackUrl(targetUrl)
            var isCallbackPath = root.isCallbackPathUrl(targetUrl)
            var code = root.extractAuthCode(targetUrl)
            var state = root.extractState(targetUrl)

            if (isExpected || isCallbackPath) {
                // Capture code and avoid loading callback 404 page in WebView.
                if (code.length > 0) {
                    var callbackPathState = root.extractStateFromCallbackPath(targetUrl)
                    if (callbackPathState.length > 0) {
                        state = callbackPathState
                    }
                    root.pendingHandover = true
                    root.pendingHandoverCode = code
                    root.pendingHandoverState = state
                    root.pendingCode = code
                    root.pendingState = state
                    deferredHandoverTimer.restart()
                    return
                }
            }
        }

        onUrlChanged: {
            if (root.codeAlreadyReceived) {
                return
            }

            var urlStr = url.toString()
            if (urlStr.length > 0 && urlStr !== "about:blank") {
                root.lastNonBlankUrl = urlStr
            }
            var isExpected = root.isExpectedCallbackUrl(urlStr)
            var isSsoCallback = root.isSsoCallbackUrl(urlStr)
            var code = root.extractAuthCode(urlStr)
            var state = root.extractState(urlStr)

            // WeChat login may put original OAuth state into callback path segment.
            // Example: /callback/<state>?code=...&state=<providerState>
            var callbackPathState = root.extractStateFromCallbackPath(urlStr)
            if (callbackPathState.length > 0) {
                state = callbackPathState
            }

            // If we have captured code already, but now lost it on later navigations,
            // recover from the saved handover info once redirect_uri is reached.
            if (!code.length && root.pendingHandover && isExpected) {
                code = root.pendingHandoverCode
                state = root.pendingHandoverState
            }

            if (code.length > 0) {
                // Capture/refresh code but keep WebView flow running to allow server-side
                // phone-binding page to appear if required.
                root.pendingHandover = true
                root.pendingHandoverCode = code
                root.pendingHandoverState = state

                // SSO intermediate redirect: show processing UI but let WebView continue to final redirect
                if (isSsoCallback) {
                    if (!root.hasNotifiedRedirecting) {
                        root.hasNotifiedRedirecting = true
                        root.oauthRedirecting()
                    }
                    return
                }

                // When final redirect_uri is reached, verify state and defer handover a bit.
                if (isExpected) {
                    var expectedState = (root.expectedStateValue || "").trim()
                    if (expectedState.length === 0) {
                        root.isLoginFlowActive = false
                        webView.stop()
                        webView.url = ""
                        root.loadError("OAuth state missing")
                        return
                    }
                    if (expectedState.length > 0 && state !== expectedState) {
                        var fallbackState = root.extractStateFromCallbackPath(urlStr)
                        if (fallbackState.length === 0 || fallbackState !== expectedState) {
                            root.isLoginFlowActive = false
                            webView.stop()
                            webView.url = ""
                            root.loadError("OAuth state mismatch")
                            return
                        }
                        state = fallbackState
                    }
                    // Ensure handover state matches expected state on final callback.
                    if (expectedState.length > 0) {
                        state = expectedState
                        root.pendingHandoverState = expectedState
                    }

                    // If callback uses /callback/<state> path, stop loading to avoid 404 page.
                    if (root.isCallbackPathUrl(urlStr)) {
                        root.pendingCode = code
                        root.pendingState = state
                        deferredHandoverTimer.restart()
                        return
                    }

                    root.pendingCode = code
                    root.pendingState = state
                    deferredHandoverTimer.restart()
                    return
                }

                // Web callback scenario (state contains a URL) should continue in WebView
                if (state.indexOf("http://") === 0 || state.indexOf("https://") === 0) {
                    if (!root.hasNotifiedRedirecting) {
                        root.hasNotifiedRedirecting = true
                        root.oauthRedirecting()
                    }
                    return
                }

                // If we reach the SSO callback with a URL-encoded state, don't verify against expected state.
                if (isSsoCallback) {
                    if (!root.hasNotifiedRedirecting) {
                        root.hasNotifiedRedirecting = true
                        root.oauthRedirecting()
                    }
                    return
                }

                // Other unexpected URLs: wait
                if (!root.hasNotifiedRedirecting) {
                    root.hasNotifiedRedirecting = true
                    root.oauthRedirecting()
                }
            } else if (root.pendingHandover && isExpected) {
                // We reached redirect_uri without a code in URL; defer handover with cached code.
                deferredHandoverTimer.restart()
            }
        }
        
        profile: WebEngineProfile {
            id: casdoorProfile
            offTheRecord: true
            httpUserAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            Component.onCompleted: {
                CasdoorHelper.setCasdoorWebProfile(casdoorProfile)
            }
        }
    }

}
