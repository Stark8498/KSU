(function () {
    if (typeof Vue === 'undefined' || typeof Vue.component !== 'function') return;
    var PLUS = 'M12 6v12M6 12h12';
    var MINUS = 'M6 12h12';
    Vue.component('gap-lock', {
        props: { open: Boolean },
        template: '<button class="gap-lock" :class="{ open: open }" @click="$emit(\'toggle\')">' +
            '<svg viewBox="0 0 24 24"><path :d="open ? minus : plus"/></svg>' +
            '</button>',
        data: function () {
            return { plus: PLUS, minus: MINUS };
        }
    });
})();

(function () {
    if (typeof SettingsMixin !== 'function') return;
    var base = SettingsMixin;

    function parentSettings() {
        try {
            return window.parent !== window ? window.parent.KSU_ALL_SETTINGS : null;
        } catch (e) {
            return null;
        }
    }

    window.SettingsMixin = function (section) {
        var mixin = base(section);
        var prev = mixin.created;
        mixin.created = function () {
            if (typeof prev === 'function') prev.call(this);
            var all = parentSettings();
            if (all && all[section]) this.loadSettings(all[section]);
        };
        return mixin;
    };
})();
