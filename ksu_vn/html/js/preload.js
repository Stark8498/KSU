(function () {
    if (typeof SettingsMixin === 'function') {
        var base = SettingsMixin;
        window.SettingsMixin = function (section) {
            var mixin = base(section), prev = mixin.created;
            mixin.created = function () {
                prev.call(this);
                var all = null;
                try { all = window.parent !== window && window.parent.KSU_ALL_SETTINGS; } catch (e) {}
                if (all && all[section]) this.loadSettings(all[section]);
            };
            return mixin;
        };
    }
    Vue.component('gap-lock', {
        props: { open: Boolean },
        template: '<button class="gap-lock" @click="$emit(\'toggle\')">' +
            '<svg viewBox="0 0 24 24"><path :d="open ? \'M6 12h12\' : \'M12 6v12M6 12h12\'"/></svg></button>'
    });
    Vue.component('tool-tabs', {
        props: { current: String },
        template: '<div class="tool-tabs">' +
            '<button v-for="t in tabs" :key="t[0]" class="tool-tab" :class="{ active: t[0] === current }" @click="go(t[0])">' +
            '<img :src="\'../icons/\' + t[1] + \'.svg\'"></button>' +
            '<span class="tool-tab-sep">|</span>' +
            '<button class="tool-tab tool-tab-set" @click="settings"><img src="../icons/caidat.svg"></button>' +
            '</div>',
        data: function () {
            return { tabs: [
                ['nesting', 'nesting'], ['thong_ke', 'thongke'],
                ['in_tem', 'intem'], ['gia_cong', 'giacong']
            ] };
        },
        methods: {
            go: function (tab) {
                if (tab !== this.current && window.parent !== window) window.parent.postMessage({ action: 'switch_tab', tabId: tab }, '*');
            },
            settings: function () { ksuToolCall('cai_dat')('open', ''); }
        }
    });
    Vue.component('note-bar', {
        props: { lines: { type: Array, default: function () { return []; } }, expanded: { default: null } },
        data: function () { return { open: true }; },
        computed: {
            isOpen: function () { return this.expanded === null ? this.open : !!this.expanded; },
            hasError: function () { var t = this.textOf; return this.lines.some(function (l) { return /^Lỗi:/.test(t(l)); }); },
            hasWarn: function () { var t = this.textOf; return this.lines.some(function (l) { return /^Cảnh báo:/.test(t(l)); }); }
        },
        mounted: function () {
            var el = this.$refs.bar, fit = function () { ksuFitBar(el); };
            if (typeof ResizeObserver !== 'undefined') new ResizeObserver(fit).observe(el);
            else window.addEventListener('resize', fit);
            fit();
        },
        updated: function () { ksuFitBar(this.$refs.bar); },
        methods: {
            toggle: function () {
                if (this.expanded === null) this.open = !this.open; else this.$emit('toggle', !this.expanded);
            },
            textOf: function (l) { return typeof l === 'string' ? l : String(l && l.text || ''); },
            parts: function (l) {
                var text = this.textOf(l), ids = l && typeof l === 'object' && Array.isArray(l.ids) ? l.ids.map(String) : [];
                if (!ids.length) return [{ t: text }];
                var esc = function (id) { return id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); };
                var re = new RegExp('(^|[^0-9A-Za-z_])(' + ids.map(esc).join('|') + ')(?![0-9A-Za-z_])', 'g'), m, out = [], pos = 0;
                while ((m = re.exec(text))) {
                    var at = m.index + m[1].length;
                    if (at > pos) out.push({ t: text.slice(pos, at) });
                    out.push({ t: m[2], id: m[2] });
                    pos = at + m[2].length;
                }
                if (pos < text.length) out.push({ t: text.slice(pos) });
                return out;
            }
        },
        template: '<div class="note-foot">' +
            '<div class="note-body" v-show="isOpen">' +
            '<div class="note-empty" v-if="!lines.length">Không có thông báo.</div>' +
            '<div v-for="(l, i) in lines" :key="i" class="note-line" :class="{ err: /^Lỗi:/.test(textOf(l)) }">' +
            '<template v-for="(p, j) in parts(l)"><a v-if="p.id" :key="j" href="#" class="note-link" @click.prevent="$emit(\'pick\', p.id, l)">{{ p.t }}</a><span v-else :key="j">{{ p.t }}</span></template>' +
            '</div>' +
            '</div>' +
            '<div ref="bar" class="note-bar">' +
            '<button class="note-head" :class="{ open: isOpen }" type="button" @click="toggle">' +
            '<svg viewBox="0 0 10 10"><path d="M3.5 2l3 3-3 3"/></svg>' +
            '<span>Thông báo</span><b :class="{ err: hasError, warn: !hasError && hasWarn }">{{ lines.length }}</b>' +
            '</button>' +
            '<slot></slot>' +
            '</div>' +
            '</div>'
    });
    Vue.component('drag-handle', {
        template: '<i class="tool-drag-handle"><svg width="6" height="10" viewBox="0 0 6 10">' +
            '<circle cx="1" cy="1" r="1"></circle> <circle cx="5" cy="1" r="1"></circle> <circle cx="1" cy="5" r="1"></circle> ' +
            '<circle cx="5" cy="5" r="1"></circle> <circle cx="1" cy="9" r="1"></circle> <circle cx="5" cy="9" r="1"></circle></svg></i>'
    });
    window.ksuFitBar = function (el) {
        if (!el || !el.clientWidth) return;
        var cls = el.className.replace(/ h\d+/g, '');
        el.className = cls;
        for (var lv = 1; lv <= 11 && el.scrollWidth > el.clientWidth; lv++) el.className = cls += ' h' + lv;
    };
    window.ksuToolCall = function (tab) {
        return function (fn, arg) {
            if (window.parent !== window) window.parent.postMessage({ action: 'tool_call', tabId: tab, fn: fn, arg: arg }, '*');
        };
    };
    window.ksuOnShown = function (vm, call, loading) {
        window.addEventListener('message', function (e) {
            if (!e.data || e.data.action !== 'tab_shown' || (vm._loaded && !e.data.reload)) return;
            vm._loaded = true;
            if (loading) vm.loading = true;
            call('load_data', '');
        });
    };
    window.ksuPlacePopup = function (vm, name, ref, r) {
        vm.$nextTick(function () {
            var t = vm.$refs[ref];
            if (!t || !vm[name]) return;
            var pop = t.closest('.text-popup'), w = pop.offsetWidth, h = pop.offsetHeight, de = document.documentElement;
            vm[name].x = Math.round(Math.min(de.clientWidth - w - 6, Math.max(6, r.left + r.width / 2 - w / 2)));
            vm[name].y = Math.round(Math.max(6, r.bottom + 4 + h > de.clientHeight - 6 ? r.top - 4 - h : r.bottom + 4));
            t.focus();
            t.setSelectionRange(t.value.length, t.value.length);
        });
    };
})();
