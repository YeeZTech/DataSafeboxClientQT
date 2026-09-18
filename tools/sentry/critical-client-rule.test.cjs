const assert = require('node:assert/strict');
const test = require('node:test');
const rule = require('./critical-client-rule.json');

// Offline model of only the Sentry legacy filter/condition forms used here.
// See README.md for the upstream implementations. No events or email are sent.
function matches(values, filter) {
    const expected = filter.value.toLowerCase();
    return values.filter(value => value !== null && value !== undefined).some(value => {
        const actual = String(value).toLowerCase();
        if (filter.match === 'eq') return actual === expected;
        if (filter.match === 'co') return actual.includes(expected);
        throw new Error(`Unsupported match: ${filter.match}`);
    });
}

function passesFilter(event, filter) {
    switch (filter.id) {
    case 'sentry.rules.filters.level.LevelFilter': {
        assert.equal(filter.match, 'eq');
        const levels = { fatal: 50, error: 40, warning: 30, info: 20, debug: 10 };
        return levels[event.level] === Number(filter.level);
    }
    case 'sentry.rules.filters.tagged_event.TaggedEventFilter':
        return matches(Object.entries(event.tags ?? {})
            .filter(([key]) => key.toLowerCase() === filter.key.toLowerCase())
            .map(([, value]) => value), filter);
    case 'sentry.rules.filters.event_attribute.EventAttributeFilter':
        if (filter.attribute === 'message') {
            return matches([event.message, event.search_message], filter);
        }
        assert.equal(filter.attribute, 'error.unhandled');
        return matches((event.exception?.values ?? [])
            .filter(value => typeof value?.mechanism?.handled === 'boolean')
            .map(value => !value.mechanism.handled), filter);
    default:
        throw new Error(`Unsupported filter: ${filter.id}`);
    }
}

function qualifies(event, state = { is_new: true }) {
    assert.equal(rule.actionMatch, 'any');
    assert.equal(rule.filterMatch, 'any');
    const conditions = {
        'sentry.rules.conditions.first_seen_event.FirstSeenEventCondition': state.is_new,
        'sentry.rules.conditions.regression_event.RegressionEventCondition': state.is_regression,
        'sentry.rules.conditions.reappeared_event.ReappearedEventCondition': state.has_escalated,
    };
    return rule.conditions.some(condition => {
        assert.ok(Object.hasOwn(conditions, condition.id), condition.id);
        return conditions[condition.id];
    }) && rule.filters.some(filter => passesFilter(event, filter));
}

test('preserves recipients, all environments, and a 60 minute action interval', () => {
    assert.equal(rule.environment, null);
    assert.equal(rule.frequency, 60);
    assert.equal(rule.conditions.length, 3);
    assert.equal(rule.filters.length, 7);
    assert.deepEqual(rule.actions, [{
        id: 'sentry.mail.actions.NotifyEmailAction',
        targetType: 'IssueOwners',
        targetIdentifier: null,
        fallthroughType: 'ActiveMembers',
    }]);
});

for (const environment of ['test', 'production']) {
    test(`${environment}: excludes ordinary network, business, Qt, and payment events`, () => {
        const messages = [
            'Connection closed', 'Host not found', 'Insufficient balance',
            'Duplicate request', 'Domain record not found', 'File not found',
            'Encryption failed', 'Operation cancelled', 'Payment confirmed',
            'QML binding loop detected', 'Unable to set window geometry',
            'Font family not found', 'CryptoOperationFinish: output file missing',
        ];
        for (const message of messages) {
            for (const level of ['info', 'warning', 'error']) {
                assert.equal(qualifies({ environment, level, message }), false, `${level}: ${message}`);
            }
        }
    });

    test(`${environment}: keeps fatal, unhandled, tagged, and legacy critical events`, () => {
        const critical = [
            { level: 'fatal', message: '<unknown>' },
            { level: 'error', exception: { values: [{ mechanism: { handled: false } }] } },
            { level: 'error', tags: { alert_worthy: 'true' }, message: 'startup.qml_load_failed' },
            { level: 'error', message: 'UserAssets initialization failed: database unavailable' },
            { level: 'warning', message: 'No WebView plug-in found!' },
            { level: 'warning', message: 'MSL function for entry point main0 not found' },
            { level: 'warning', message: 'Failed to build graphics pipeline state' },
        ];
        for (const event of critical) {
            assert.equal(qualifies({ environment, ...event }), true, JSON.stringify(event));
        }
    });
}

test('handled or unspecified exception mechanisms do not mean unhandled', () => {
    for (const value of [{}, { mechanism: {} }, { mechanism: { handled: null } }, { mechanism: { handled: true } }]) {
        assert.equal(qualifies({ level: 'error', exception: { values: [value] } }), false);
    }
    assert.equal(qualifies({ exception: { values: [
        { mechanism: { handled: true } }, { mechanism: { handled: false } },
    ] } }), true);
    assert.equal(qualifies({ tags: { alert_worthy: 'false' } }), false);
});

test('attribute and tag comparisons are case insensitive and search_message is checked', () => {
    assert.equal(qualifies({ tags: { ALERT_WORTHY: 'TRUE' } }), true);
    assert.equal(qualifies({ message: 'Qt warning', search_message: 'NO WEBVIEW PLUG-IN FOUND!' }), true);
});

test('only first seen, regression, or escalation state triggers notification', () => {
    const event = { level: 'fatal' };
    for (const state of [{ is_new: true }, { is_regression: true }, { has_escalated: true }]) {
        assert.equal(qualifies(event, state), true);
    }
    assert.equal(qualifies(event, {}), false);
    assert.equal(qualifies(event, { is_new_group_environment: true }), false);
});
