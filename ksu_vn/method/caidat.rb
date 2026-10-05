module KSU::Caidat
  HTML = <<~'HTML'
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <title>KSU - Cài đặt</title>
    BASE_PLACEHOLDER
    <link rel="stylesheet" href="css/style.css?v=3">
    <script src="js/vue.min.js"></script>
    <script>window.KSU_ALL_SETTINGS = SETTINGS_PLACEHOLDER;</script>
    <script>document.addEventListener('contextmenu',function(e){e.preventDefault();},false);</script>
</head>
<body>

<div id="settings-container">
    <div id="loading-overlay" class="loading-overlay">
        <div class="spinner"></div>
        <div class="loading-text">Đang tải cài đặt...</div>
    </div>

    <div id="tabs">
        <div class="search-box">
            <input type="text" id="search-input" placeholder="Tìm kiếm..." oninput="handleSearch(this.value)" spellcheck="false" autocomplete="off">
            <button class="search-clear" onclick="document.getElementById('search-input').value='';handleSearch('');">×</button>
        </div>
        <div class="tabs-list">
            <div class="tab active" data-tab="cai_dat"><img src="../icons/caidat.svg" class="tab-icon">Cài đặt</div>
            <div class="tab" data-tab="xep_tam"><img src="../icons/xeptam.svg" class="tab-icon">Xếp tấm</div>
            <div class="tab" data-tab="chon_tam"><img src="../icons/chontam.svg" class="tab-icon">Chọn tấm</div>
            <div class="tab" data-tab="them_tam"><img src="../icons/themtam.svg" class="tab-icon">Thêm tấm</div>
            <div class="tab" data-tab="xep_hang"><img src="../icons/xephang.svg" class="tab-icon">Xếp hàng</div>
            <div class="tab" data-tab="danh_so_van"><img src="../icons/danhso.svg" class="tab-icon">Đánh số</div>
            <div class="tab" data-tab="gan_nhan"><img src="../icons/gannhan.svg" class="tab-icon">Gắn nhãn</div>
            <div class="tab" data-tab="net_cat_cuoi"><img src="../icons/catcuoi.svg" class="tab-icon">Cắt cuối</div>
            <div class="tab" data-tab="chong_bay"><img src="../icons/chongbay.svg" class="tab-icon">Chống bay</div>
            <div class="tab" data-tab="toi_uu_van"><img src="../icons/toiuu.svg" class="tab-icon">Tối ưu</div>
            <div class="tab" data-tab="nesting"><img src="../icons/nesting.svg" class="tab-icon">Nesting</div>
            <div class="tab" data-tab="thong_ke"><img src="../icons/thongke.svg" class="tab-icon">Thống kê</div>
            <div class="tab" data-tab="in_tem"><img src="../icons/intem.svg" class="tab-icon">In tem nhãn</div>
        </div>


    </div>

    <div id="tab-content">
        <div class="tab-panel active" id="panel_cai_dat">
            <iframe id="iframe_cai_dat" data-tab="cai_dat" data-src="caidat.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_xep_tam">
            <iframe id="iframe_xep_tam" data-tab="xep_tam" data-src="xeptam.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_chon_tam">
            <iframe id="iframe_chon_tam" data-tab="chon_tam" data-src="chontam.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_them_tam">
            <iframe id="iframe_them_tam" data-tab="them_tam" data-src="themtam.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_xep_hang">
            <iframe id="iframe_xep_hang" data-tab="xep_hang" data-src="xephang.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_danh_so_van">
            <iframe id="iframe_danh_so_van" data-tab="danh_so_van" data-src="danhso.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_gan_nhan">
            <iframe id="iframe_gan_nhan" data-tab="gan_nhan" data-src="gannhan.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_net_cat_cuoi">
            <iframe id="iframe_net_cat_cuoi" data-tab="net_cat_cuoi" data-src="catcuoi.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_chong_bay">
            <iframe id="iframe_chong_bay" data-tab="chong_bay" data-src="chongbay.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_toi_uu_van">
            <iframe id="iframe_toi_uu_van" data-tab="toi_uu_van" data-src="toiuu.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_nesting">
            <iframe id="iframe_nesting" data-tab="nesting" data-src="nesting.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_thong_ke">
            <iframe id="iframe_thong_ke" data-tab="thong_ke" data-src="thongke.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_in_tem">
            <iframe id="iframe_in_tem" data-tab="in_tem" data-src="intem.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_gia_cong">
            <iframe id="iframe_gia_cong" data-tab="gia_cong" data-src="giacong.html" data-boot="1" frameborder="0"></iframe>
        </div>
    </div>
</div>

<script>
    const tabs = document.querySelectorAll('.tab');
    let currentTabId = 'cai_dat';
    let allSettings = {};
    let isSettingsLoaded = false;
    var searchIndex = {};
    var searchQuery = '';
    var GROUP = false;

    let iframesReady = {};
    document.querySelectorAll('iframe').forEach(iframe => {
        const tabId = iframe.getAttribute('data-tab');
        if (tabId) iframesReady[tabId] = false;
    });

    let pendingLoads = new Set();

    function postTo(tabId, msg) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow) iframe.contentWindow.postMessage(msg, '*');
    }

    function toRuby(name, arg) {
        if (window.sketchup) window.sketchup[name](arg);
        else window.location.href = 'skp:' + name + '@' + arg;
    }

    function handleSearch(value) {
        searchQuery = value.trim().toLowerCase();
        tabs.forEach(function(tab) {
            var tabId = tab.getAttribute('data-tab');
            if (!searchQuery) {
                tab.classList.remove('search-hidden');
                return;
            }
            var tabName = tab.textContent.trim().toLowerCase();
            var items = searchIndex[tabId] || [];
            var match = tabName.includes(searchQuery) || items.some(function(item) {
                return item.toLowerCase().includes(searchQuery);
            });
            tab.classList.toggle('search-hidden', !match);
        });
        postTo(currentTabId, { action: 'search_highlight', query: searchQuery });
    }

    function ensureIframe(tabId) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (!iframe) return;
        var boot = iframe.getAttribute('data-boot');
        if (boot === '1') {
            if (!window.sketchup) return setTimeout(function () { ensureIframe(tabId); }, 100);
            iframe.setAttribute('data-boot', '2');
            window.sketchup.tool_call(tabId + '@boot@');
            return;
        }
        if (boot === 'stale') iframe.removeAttribute('data-boot');
        else if (boot || iframe.getAttribute('src')) return;
        var src = iframe.getAttribute('data-src');
        if (src) iframe.setAttribute('src', src);
    }

    window.xncBoot = function (data) {
        var iframe = document.getElementById('iframe_gia_cong');
        if (!iframe) return;
        window.XNC_JSON = JSON.stringify(data);
        if (iframe.getAttribute('src') && currentTabId !== 'gia_cong') return iframe.setAttribute('data-boot', 'stale');
        iframe.removeAttribute('data-boot');
        iframe.setAttribute('src', iframe.getAttribute('data-src'));
    };

    window.xncBootFailed = function () {
        var iframe = document.getElementById('iframe_gia_cong');
        if (iframe && iframe.getAttribute('data-boot') === '2') iframe.setAttribute('data-boot', '1');
    };

    window.xncReceive = function (name, payload) {
        postTo('gia_cong', { action: 'xnc_push', name: name, payload: payload });
    };

    function focusIframe(tabId) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow) iframe.contentWindow.focus();
    }

    function loadRestIframes() {
        if (GROUP) return;
        var queue = [];
        document.querySelectorAll('iframe').forEach(function (iframe) {
            var tabId = iframe.getAttribute('data-tab');
            if (tabId && tabId !== currentTabId) queue.push(tabId);
        });
        var i = 0;
        var step = function () {
            if (i >= queue.length) return;
            ensureIframe(queue[i++]);
            setTimeout(step, 120);
        };
        step();
    }

    var staleTabs = {};
    window.markStale = function (list) {
        list.forEach(function (t) { if (t === currentTabId) sendTabShown(t, true); else staleTabs[t] = true; });
    };

    function switchToTab(tabId, reload) {
        if (currentTabId === tabId) return;
        if (staleTabs[tabId]) reload = true;
        delete staleTabs[tabId];
        ensureIframe(tabId);
        postTo(currentTabId, { action: 'tab_hidden', tabId: currentTabId });

        var activeTab = document.querySelector('.tab.active');
        if (activeTab) activeTab.classList.remove('active');

        var activePanel = document.querySelector('.tab-panel.active');
        if (activePanel) activePanel.classList.remove('active');

        const tab = document.querySelector('.tab[data-tab="' + tabId + '"]');
        const panel = document.getElementById('panel_' + tabId);
        if (panel) {
            if (tab) tab.classList.add('active');
            panel.classList.add('active');

            if (isSettingsLoaded && iframesReady[tabId]) {
                if (!GROUP) loadSettingsToIframe(tabId);
            } else if (isSettingsLoaded) {
                pendingLoads.add(tabId);
            }
        }

        currentTabId = tabId;
        applyTabSidebar(tabId);
        sendTabShown(tabId, reload);
        if (window.sketchup) window.sketchup.tab_changed(tabId);
        if (searchQuery) postTo(tabId, { action: 'search_highlight', query: searchQuery });
        if (GROUP) focusIframe(tabId);
    }

    function applyTabSidebar(tabId) {
        if (GROUP) return;
        setSidebarCollapsed(savedCollapsed());
    }

    function savedCollapsed() {
        return !!(allSettings.cai_dat && allSettings.cai_dat.sidebar_collapsed);
    }

    function sendTabShown(tabId, reload) {
        postTo(tabId, { action: 'tab_shown', tabId: tabId, reload: !!reload });
    }

    window.callTabFn = function (tabId, fn, data) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow && typeof iframe.contentWindow[fn] === 'function') {
            iframe.contentWindow[fn](data);
        }
    }

    window.selectPresetByName = function(name) {
        postTo(currentTabId, { action: 'select_preset', name: name });
    }

    function loadSettingsToIframe(tabId) {
        postTo(tabId, { action: 'loadSettings', settings: allSettings[tabId] || {}, hideUnavailable: true });
    }

    function hideLoading() {
        const overlay = document.getElementById('loading-overlay');
        if (overlay) overlay.style.display = 'none';
    }

    tabs.forEach(function (tab) {
        tab.addEventListener('click', function () {
            switchToTab(tab.getAttribute('data-tab'));
        });
    });

    var RUBY_ACTIONS = ['export_settings', 'import_settings', 'reset_settings', 'export_online', 'import_online', 'view_hardware_id', 'remove_activation', 'check_update_version', 'restore_from_backup', 'uninstall'];

    window.addEventListener('message', function (event) {
        if (event.data && event.data.action === 'iframe_ready') {
            const tabId = event.data.tabId;
            iframesReady[tabId] = true;

            var iframe = document.getElementById('iframe_' + tabId);
            if (iframe && iframe.contentDocument) {
                var currentTheme = document.documentElement.getAttribute('data-theme');
                if (currentTheme) {
                    iframe.contentDocument.documentElement.setAttribute('data-theme', currentTheme);
                }
            }
            var savedCol3Width = allSettings.cai_dat && allSettings.cai_dat.col3_width;
            if (iframe && iframe.contentWindow && savedCol3Width) {
                iframe.contentWindow.postMessage({ action: 'apply_col3_width', width: parseFloat(savedCol3Width) }, '*');
            }

            if (isSettingsLoaded && (tabId === currentTabId || pendingLoads.has(tabId))) {
                setTimeout(function () {
                    loadSettingsToIframe(tabId);
                    pendingLoads.delete(tabId);
                }, 100);
            }

            if (tabId === currentTabId) {
                hideLoading();
                sendTabShown(tabId);
                if (GROUP) focusIframe(tabId);
            }
        } else if (event.data && event.data.action === 'switch_tab') {
            switchToTab(event.data.tabId);
        } else if (event.data && event.data.action === 'search_index') {
            searchIndex[event.data.tabId] = event.data.items;
        } else if (event.data && event.data.action === 'tool_call') {
            var arg = event.data.arg;
            if (arg === undefined || arg === null) arg = '';
            toRuby('tool_call', event.data.tabId + '@' + event.data.fn + '@' + arg);
        } else if (event.data && RUBY_ACTIONS.indexOf(event.data.action) >= 0) {
            if (window.sketchup) window.sketchup[event.data.action]();
            else window.location.href = 'skp:' + event.data.action;
        } else if (event.data && event.data.action === 'reset_section') {
            toRuby('reset_section', event.data.tabId);
        } else if (event.data && event.data.action === 'set_col3_width') {
            var col3w = parseFloat(event.data.width);
            if (!allSettings.cai_dat) allSettings.cai_dat = {};
            allSettings.cai_dat.col3_width = col3w;
            broadcastCol3Width(col3w);
            toRuby('save_setting', 'cai_dat@col3_width@' + col3w);
        } else if (event.data && event.data.action === 'toggle_sidebar') {
            toggleSidebar();
        } else if (event.data && event.data.action === 'set_theme') {
            applyTheme(event.data.theme);
        } else if (event.data && event.data.action === 'save_setting') {
            const tabId = event.data.tabId || currentTabId;
            if (!allSettings[tabId]) allSettings[tabId] = {};
            allSettings[tabId][event.data.key] = event.data.value;
            const val = (typeof event.data.value === 'object') ? JSON.stringify(event.data.value) : event.data.value;
            toRuby('save_setting', tabId + '@' + event.data.key + '@' + val);
        } else if (event.data && event.data.action === 'load_presets') {
            if (window.sketchup) {
                window.sketchup.load_presets(event.data.tabId, function (response) {
                    try {
                        const presets = JSON.parse(response);
                        sendPresetsToIframe(event.data.tabId, presets);
                    } catch (e) {
                        console.error('[Settings] Failed to parse presets:', e);
                    }
                });
            } else {
                window.location.href = 'skp:load_presets@' + event.data.tabId;
            }
        } else if (event.data && event.data.action === 'save_preset') {
            toRuby('save_preset', event.data.tabId + '@' + event.data.presetName + '@' + JSON.stringify(event.data.settings));
        } else if (event.data && event.data.action === 'load_preset') {
            toRuby('load_preset', event.data.tabId + '@' + event.data.presetName);
        } else if (event.data && event.data.action === 'delete_preset') {
            toRuby('delete_preset', event.data.tabId + '@' + event.data.presetName);
        } else if (event.data && event.data.action === 'save_presets_order') {
            toRuby('save_presets_order', event.data.tabId + '@' + JSON.stringify(event.data.presets));
        } else if (event.data && event.data.action === 'save_collapsed_groups') {
            toRuby('save_collapsed_groups', event.data.tabId + '@' + JSON.stringify(event.data.collapsedGroups));
        }
    });

    function sendPresetsToIframe(tabId, presets, collapsedGroups) {
        postTo(tabId, { action: 'presets_loaded', presets: presets, collapsedGroups: collapsedGroups });
    }

    function sendSettingsToIframe(tabId, settings) {
        if (settings && typeof settings === 'object') {
            if (!allSettings[tabId]) allSettings[tabId] = {};
            Object.keys(settings).forEach(function (k) { allSettings[tabId][k] = settings[k]; });
        }
        postTo(tabId, { action: 'preset_settings_loaded', settings: settings });
    }

    window.sendPresetsToIframe = sendPresetsToIframe;
    window.sendSettingsToIframe = sendSettingsToIframe;

    window.loadAllSettings = function (settingsData) {
        allSettings = settingsData;
        isSettingsLoaded = true;

        Object.keys(iframesReady).forEach(function (tabId) {
            if (iframesReady[tabId]) {
                setTimeout(function () {
                    loadSettingsToIframe(tabId);
                }, 100);
            }
        });

        if (allSettings.cai_dat && allSettings.cai_dat.giao_dien_cai_dat_toi) {
            applyTheme('dark');
        }
        applyTabSidebar(currentTabId);
        if (allSettings.cai_dat && allSettings.cai_dat.col3_width) {
            broadcastCol3Width(parseFloat(allSettings.cai_dat.col3_width));
        }
    };

    if (window.KSU_ALL_SETTINGS) loadAllSettings(window.KSU_ALL_SETTINGS);
    ensureIframe(currentTabId);
    setTimeout(hideLoading, 3000);
    setTimeout(loadRestIframes, 400);

    function applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        document.querySelectorAll('iframe').forEach(function(iframe) {
            try {
                if (iframe.contentDocument) {
                    iframe.contentDocument.documentElement.setAttribute('data-theme', theme);
                }
            } catch(e) {}
        });
    }

    function broadcastCol3Width(w) {
        document.querySelectorAll('iframe').forEach(function(iframe) {
            try {
                if (iframe.contentWindow) {
                    iframe.contentWindow.postMessage({ action: 'apply_col3_width', width: w }, '*');
                }
            } catch(e) {}
        });
    }

    function setSidebarCollapsed(collapsed) {
        var tabs = document.getElementById('tabs');
        if (collapsed) tabs.classList.add('hide-text', 'collapsed');
        else tabs.classList.remove('collapsed', 'hide-text');
    }

    function isTypingTarget(el) {
        if (!el) return false;
        var tag = (el.tagName || '').toLowerCase();
        return tag === 'input' || tag === 'textarea' || tag === 'select' || el.isContentEditable;
    }

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Tab' && !e.ctrlKey && !e.altKey && !e.metaKey && !e.shiftKey && !isTypingTarget(e.target)) {
            e.preventDefault();
            toggleSidebar();
        }
    });

    function toggleSidebar() {
        if (GROUP) return;
        var isCollapsing = !document.getElementById('tabs').classList.contains('collapsed');
        setSidebarCollapsed(isCollapsing);
        if (!allSettings.cai_dat) allSettings.cai_dat = {};
        allSettings.cai_dat.sidebar_collapsed = isCollapsing;
        toRuby('save_setting', 'cai_dat@sidebar_collapsed@' + isCollapsing);
    }

</script>

</body>
</html>
  HTML

  def self.inject_addons(out)
    arr = KSU::Addon.keys.map { |k| "                #{k}: true," }.join("\n")
    tools = KSU::Addon.labels.map { |k, v| "                {key: '#{k}', label: '#{v[0]}'}," }.join("\n")
    out = out.sub(/^\s*\/\/ ksu-addon-startup\n/) { arr.empty? ? "" : "#{arr}\n" }
    out.sub(/^\s*\/\/ ksu-addon-tools\n/) { tools.empty? ? "" : "#{tools}\n" }
  end
  def self.strip_tabs(out, keys)
    keys.each do |k|
      out = out.sub(/^[ \t]*<div class="tab(?: active)?" data-tab="#{k}">.*\n/, "")
      out = out.sub(/^[ \t]*<div class="tab-panel(?: active)?" id="panel_#{k}">\n.*\n[ \t]*<\/div>\n/, "")
    end
    out
  end
  def self.build_html(kind2 = "cai_dat", str = "{}", _124c7bd3 = false)
    kind2 = "cai_dat" unless kind2.to_s =~ /\A[a-z_]+\z/
    out = inject_addons(HTML.sub("BASE_PLACEHOLDER", "<base href=\"file:///#{File.join(__dir__, "..", "html", "").gsub("\\", "/")}\">"))
    out = out.sub("SETTINGS_PLACEHOLDER") { str.to_s.gsub("</", "<\\/") }
    if KSU::Settings.get("giao_dien_cai_dat_toi", false, "cai_dat").to_s == "true"
      out = out.sub("<html lang=\"vi\">", "<html lang=\"vi\" data-theme=\"dark\" style=\"background:#1c1c1e\">")
    end
    tools = KSU::Settings::TOOL_WINDOWS
    out = strip_tabs(out, _124c7bd3 ? HTML.scan(/id="panel_([a-z_]+)"/).flatten - tools : tools)
    if _124c7bd3
      out = out.sub("<div id=\"settings-container\">", "<div id=\"settings-container\" class=\"group\">")
      out = out.sub(/^    <div id="tabs">\n.*?\n    <\/div>\n/m, "")
      out = out.sub("var GROUP = false;", "var GROUP = true;")
    end
    return out if kind2 == "cai_dat"
    out = out.sub("<div class=\"tab active\" data-tab=\"cai_dat\">", "<div class=\"tab\" data-tab=\"cai_dat\">")
    out = out.sub("<div class=\"tab\" data-tab=\"#{kind2}\">", "<div class=\"tab active\" data-tab=\"#{kind2}\">")
    out = out.sub("<div class=\"tab-panel active\" id=\"panel_cai_dat\">", "<div class=\"tab-panel\" id=\"panel_cai_dat\">")
    out = out.sub("<div class=\"tab-panel\" id=\"panel_#{kind2}\">", "<div class=\"tab-panel active\" id=\"panel_#{kind2}\">")
    out.sub("let currentTabId = 'cai_dat';", "let currentTabId = '#{kind2}';")
  end
end
module KSU::Caidat
  def self.machine_fingerprint
    id_str = KSU::Nesting.hw_config_id
    return id_str if KSU::Detail.has_id?(id_str)
    id_str = KSU::Chontam.volume_id
    return id_str if KSU::Detail.has_id?(id_str)
    id_str = KSU::Update.disk_id2
    return id_str if KSU::Detail.has_id?(id_str)
    ""
  end
end
