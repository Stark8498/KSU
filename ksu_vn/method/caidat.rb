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
    <link rel="stylesheet" href="css/style.css">
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
            <div class="tab" data-tab="danh_so_van"><img src="../icons/danhsovan.svg" class="tab-icon">Đánh số ván</div>
            <div class="tab" data-tab="gan_nhan"><img src="../icons/gannhan.svg" class="tab-icon">Gắn nhãn</div>
            <div class="tab" data-tab="net_cat_cuoi"><img src="../icons/netcatcuoi.svg" class="tab-icon">Nét cắt cuối</div>
            <div class="tab" data-tab="chong_bay"><img src="../icons/chongbay.svg" class="tab-icon">Chống bay</div>
            <div class="tab" data-tab="toi_uu_van"><img src="../icons/toiuuvan.svg" class="tab-icon">Tối ưu ván</div>
            <div class="tab" data-tab="nesting"><img src="../icons/nesting.svg" class="tab-icon">Nesting</div>
            <div class="tab" data-tab="xuat_dxf"><img src="../icons/xuatdxf.svg" class="tab-icon">Xuất DXF</div>
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
            <iframe id="iframe_danh_so_van" data-tab="danh_so_van" data-src="danhsovan.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_gan_nhan">
            <iframe id="iframe_gan_nhan" data-tab="gan_nhan" data-src="gannhan.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_net_cat_cuoi">
            <iframe id="iframe_net_cat_cuoi" data-tab="net_cat_cuoi" data-src="netcatcuoi.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_chong_bay">
            <iframe id="iframe_chong_bay" data-tab="chong_bay" data-src="chongbay.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_toi_uu_van">
            <iframe id="iframe_toi_uu_van" data-tab="toi_uu_van" data-src="toiuuvan.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_nesting">
            <iframe id="iframe_nesting" data-tab="nesting" data-src="nesting.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_xuat_dxf">
            <iframe id="iframe_xuat_dxf" data-tab="xuat_dxf" data-src="xuatdxf.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_thong_ke">
            <iframe id="iframe_thong_ke" data-tab="thong_ke" data-src="thongke.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_in_tem">
            <iframe id="iframe_in_tem" data-tab="in_tem" data-src="intem.html" frameborder="0"></iframe>
        </div>
    </div>
</div>

<script>
    const tabs = document.querySelectorAll('.tab');
    let currentTabId = 'cai_dat';
    let allSettings = {};
    let isSettingsLoaded = false;
    let hideUnavailable = true;
    var searchIndex = {};
    var searchQuery = '';
    var SOLO_TAB = '';

    let iframesReady = {};
    document.querySelectorAll('iframe').forEach(iframe => {
        const tabId = iframe.getAttribute('data-tab');
        if (tabId) iframesReady[tabId] = false;
    });

    let pendingLoads = new Set();

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
        sendSearchHighlight(currentTabId, searchQuery);
    }

    function sendSearchHighlight(tabId, query) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({ action: 'search_highlight', query: query }, '*');
        }
    }

    function ensureIframe(tabId) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (!iframe) return;
        var src = iframe.getAttribute('data-src');
        if (src && !iframe.getAttribute('src')) iframe.setAttribute('src', src);
    }

    function loadRestIframes() {
        if (SOLO_TAB) return;
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

    function switchToTab(tabId, reload) {
        if (currentTabId === tabId) return;
        ensureIframe(tabId);
        sendTabHidden(currentTabId);

        var activeTab = document.querySelector('.tab.active');
        if (activeTab) activeTab.classList.remove('active');

        var activePanel = document.querySelector('.tab-panel.active');
        if (activePanel) activePanel.classList.remove('active');

        const tab = document.querySelector('.tab[data-tab="' + tabId + '"]');
        const panel = document.getElementById('panel_' + tabId);
        if (tab && panel) {
            tab.classList.add('active');
            panel.classList.add('active');

            if (isSettingsLoaded && iframesReady[tabId]) {
                loadSettingsToIframe(tabId);
            } else if (isSettingsLoaded) {
                pendingLoads.add(tabId);
            }
        }

        currentTabId = tabId;
        applyTabSidebar(tabId);
        sendTabShown(tabId, reload);
        if (window.sketchup) window.sketchup.tab_changed(tabId);
        if (searchQuery) sendSearchHighlight(tabId, searchQuery);
    }

    function applyTabSidebar(tabId) {
        setSidebarCollapsed(savedCollapsed());
    }

    function savedCollapsed() {
        return !!(allSettings.cai_dat && allSettings.cai_dat.sidebar_collapsed);
    }

    function sendTabHidden(tabId) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({ action: 'tab_hidden', tabId: tabId }, '*');
        }
    }

    function sendTabShown(tabId, reload) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({ action: 'tab_shown', tabId: tabId, reload: !!reload }, '*');
        }
    }

    window.callTabFn = function (tabId, fn, data) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow && typeof iframe.contentWindow[fn] === 'function') {
            iframe.contentWindow[fn](data);
        }
    }

    window.selectPresetByName = function(name) {
        var iframe = document.getElementById('iframe_' + currentTabId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({ action: 'select_preset', name: name }, '*');
        }
    }

    function loadSettingsToIframe(tabId) {
        const iframeId = 'iframe_' + tabId;
        const iframe = document.getElementById(iframeId);

        if (!iframe || !iframe.contentWindow) {
            return;
        }

        const tabSettings = allSettings[tabId] || {};

        iframe.contentWindow.postMessage({
            action: 'loadSettings',
            settings: tabSettings,
            hideUnavailable: hideUnavailable
        }, '*');
    }

    function hideLoading() {
        const overlay = document.getElementById('loading-overlay');
        if (overlay) {
            overlay.style.display = 'none';
        }
    }

    tabs.forEach(function (tab) {
        tab.addEventListener('click', function () {
            const tabId = tab.getAttribute('data-tab');
            switchToTab(tabId);
        });
    });

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
            }
        } else if (event.data && event.data.action === 'search_index') {
            searchIndex[event.data.tabId] = event.data.items;
        } else if (event.data && event.data.action === 'tool_call') {
            var arg = event.data.arg;
            if (arg === undefined || arg === null) arg = '';
            var toolParams = event.data.tabId + '@' + event.data.fn + '@' + arg;
            if (window.sketchup) {
                window.sketchup.tool_call(toolParams);
            } else {
                window.location.href = 'skp:tool_call@' + toolParams;
            }
        } else if (event.data && event.data.action === 'export_settings') {
            if (window.sketchup) {
                window.sketchup.export_settings();
            } else {
                window.location.href = 'skp:export_settings';
            }
        } else if (event.data && event.data.action === 'import_settings') {
            if (window.sketchup) {
                window.sketchup.import_settings();
            } else {
                window.location.href = 'skp:import_settings';
            }
        } else if (event.data && event.data.action === 'reset_settings') {
            if (window.sketchup) {
                window.sketchup.reset_settings();
            } else {
                window.location.href = 'skp:reset_settings';
            }
        } else if (event.data && event.data.action === 'reset_section') {
            var sectionId = event.data.tabId;
            if (window.sketchup) {
                window.sketchup.reset_section(sectionId);
            } else {
                window.location.href = 'skp:reset_section@' + sectionId;
            }
        } else if (event.data && event.data.action === 'export_online') {
            if (window.sketchup) {
                window.sketchup.export_online();
            } else {
                window.location.href = 'skp:export_online';
            }
        } else if (event.data && event.data.action === 'import_online') {
            if (window.sketchup) {
                window.sketchup.import_online();
            } else {
                window.location.href = 'skp:import_online';
            }
        } else if (event.data && event.data.action === 'view_hardware_id') {
            if (window.sketchup) {
                window.sketchup.view_hardware_id();
            } else {
                window.location.href = 'skp:view_hardware_id';
            }
        } else if (event.data && event.data.action === 'remove_activation') {
            if (window.sketchup) {
                window.sketchup.remove_activation();
            } else {
                window.location.href = 'skp:remove_activation';
            }
        } else if (event.data && event.data.action === 'check_update_version') {
            if (window.sketchup) {
                window.sketchup.check_update_version();
            } else {
                window.location.href = 'skp:check_update_version';
            }
        } else if (event.data && event.data.action === 'restore_from_backup') {
            if (window.sketchup) {
                window.sketchup.restore_from_backup();
            } else {
                window.location.href = 'skp:restore_from_backup';
            }
        } else if (event.data && event.data.action === 'uninstall') {
            if (window.sketchup) {
                window.sketchup.uninstall();
            } else {
                window.location.href = 'skp:uninstall';
            }
        } else if (event.data && event.data.action === 'set_col3_width') {
            var col3w = parseFloat(event.data.width);
            if (!allSettings.cai_dat) allSettings.cai_dat = {};
            allSettings.cai_dat.col3_width = col3w;
            broadcastCol3Width(col3w);
            if (window.sketchup) {
                window.sketchup.save_setting('cai_dat@col3_width@' + col3w);
            } else {
                window.location.href = 'skp:save_setting@cai_dat@col3_width@' + col3w;
            }
        } else if (event.data && event.data.action === 'toggle_sidebar') {
            toggleSidebar();
        } else if (event.data && event.data.action === 'set_theme') {
            applyTheme(event.data.theme);
        } else if (event.data && event.data.action === 'save_setting') {
            const tabId = event.data.tabId || currentTabId;

            if (!allSettings[tabId]) {
                allSettings[tabId] = {};
            }
            allSettings[tabId][event.data.key] = event.data.value;

            const val = (typeof event.data.value === 'object') ? JSON.stringify(event.data.value) : event.data.value;
            if (window.sketchup) {
                const params = tabId + '@' + event.data.key + '@' + val;
                window.sketchup.save_setting(params);
            } else {
                window.location.href = 'skp:save_setting@' + tabId + '@' + event.data.key + '@' + val;
            }
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
            const settingsJson = JSON.stringify(event.data.settings);
            const params = event.data.tabId + '@' + event.data.presetName + '@' + settingsJson;

            if (window.sketchup) {
                window.sketchup.save_preset(params);
            } else {
                window.location.href = 'skp:save_preset@' + params;
            }
        } else if (event.data && event.data.action === 'load_preset') {
            const params = event.data.tabId + '@' + event.data.presetName;
            if (window.sketchup) {
                window.sketchup.load_preset(params);
            } else {
                window.location.href = 'skp:load_preset@' + params;
            }
        } else if (event.data && event.data.action === 'delete_preset') {
            const params = event.data.tabId + '@' + event.data.presetName;
            if (window.sketchup) {
                window.sketchup.delete_preset(params);
            } else {
                window.location.href = 'skp:delete_preset@' + params;
            }
        } else if (event.data && event.data.action === 'save_presets_order') {
            const presetsJson = JSON.stringify(event.data.presets);
            const params = event.data.tabId + '@' + presetsJson;
            if (window.sketchup) {
                window.sketchup.save_presets_order(params);
            } else {
                window.location.href = 'skp:save_presets_order@' + params;
            }
        } else if (event.data && event.data.action === 'save_collapsed_groups') {
            const groupsJson = JSON.stringify(event.data.collapsedGroups);
            const params = event.data.tabId + '@' + groupsJson;
            if (window.sketchup) {
                window.sketchup.save_collapsed_groups(params);
            } else {
                window.location.href = 'skp:save_collapsed_groups@' + params;
            }
        }
    });

    function sendPresetsToIframe(tabId, presets, collapsedGroups) {
        const iframeId = 'iframe_' + tabId;
        const iframe = document.getElementById(iframeId);

        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({
                action: 'presets_loaded',
                presets: presets,
                collapsedGroups: collapsedGroups
            }, '*');
        }
    }

    function sendSettingsToIframe(tabId, settings) {
        const iframeId = 'iframe_' + tabId;
        const iframe = document.getElementById(iframeId);

        if (settings && typeof settings === 'object') {
            if (!allSettings[tabId]) allSettings[tabId] = {};
            Object.keys(settings).forEach(function (k) { allSettings[tabId][k] = settings[k]; });
        }
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({
                action: 'preset_settings_loaded',
                settings: settings
            }, '*');
        }
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

    function setTabTextVisible(visible) {
        var tabs = document.getElementById('tabs');
        if (visible) {
            tabs.classList.remove('hide-text');
        } else {
            tabs.classList.add('hide-text');
        }
    }

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
        if (collapsed) {
            setTabTextVisible(false);
            tabs.classList.add('collapsed');
        } else {
            tabs.classList.remove('collapsed');
            setTabTextVisible(true);
        }
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
        if (SOLO_TAB) return;
        var tabs = document.getElementById('tabs');
        var isCollapsing = !tabs.classList.contains('collapsed');
        setSidebarCollapsed(isCollapsing);
        var tabId = 'cai_dat';
        var val = isCollapsing ? true : false;
        if (!allSettings.cai_dat) allSettings.cai_dat = {};
        allSettings.cai_dat.sidebar_collapsed = val;
        if (window.sketchup) {
            window.sketchup.save_setting(tabId + '@sidebar_collapsed@' + val);
        } else {
            window.location.href = 'skp:save_setting@' + tabId + '@sidebar_collapsed@' + val;
        }
    }

</script>

</body>
</html>
  HTML

  ALL_TABS = HTML.scan(/id="panel_([a-z_]+)"/).flatten.freeze
  def self.inject_addons(out)
    arr = KSU::Addon.keys.map { |k| "                #{k}: true," }.join("\n")
    arr2 = KSU::Addon.labels.map { |k, v| "                {key: '#{k}', label: '#{v[0]}'}," }.join("\n")
    out = out.sub(/^\s*\/\/ ksu-addon-startup\n/) { arr.empty? ? "" : "#{arr}\n" }
    out.sub(/^\s*\/\/ ksu-addon-tools\n/) { arr2.empty? ? "" : "#{arr2}\n" }
  end
  def self.strip_tabs(out, keys)
    keys.each do |k|
      out = out.sub(/^[ \t]*<div class="tab(?: active)?" data-tab="#{k}">.*\n/, "")
      out = out.sub(/^[ \t]*<div class="tab-panel(?: active)?" id="panel_#{k}">\n.*\n[ \t]*<\/div>\n/, "")
    end
    out
  end
  def self.build_html(kind2 = "cai_dat", str2 = "{}", solo = false)
    kind2 = "cai_dat" unless kind2.to_s =~ /\A[a-z_]+\z/
    str3 = "file:///" + File.join(__dir__, "..", "html", "").gsub("\\", "/")
    out = HTML.sub("BASE_PLACEHOLDER", "<base href=\"#{str3}\">")
    out = inject_addons(out)
    str4 = str2.to_s.gsub("</", "<\\/")
    out = out.sub("SETTINGS_PLACEHOLDER") { str4 }
    if KSU::Settings.get("giao_dien_cai_dat_toi", false, "cai_dat").to_s == "true"
      out = out.sub("<html lang=\"vi\">", "<html lang=\"vi\" data-theme=\"dark\" style=\"background:#1c1c1e\">")
    end
    if solo
      out = strip_tabs(out, ALL_TABS - [kind2])
      out = out.sub("<div id=\"settings-container\">", "<div id=\"settings-container\" class=\"solo\">")
      out = out.sub("<div class=\"tab\" data-tab=\"#{kind2}\">", "<div class=\"tab active\" data-tab=\"#{kind2}\">")
      out = out.sub("<div class=\"tab-panel\" id=\"panel_#{kind2}\">", "<div class=\"tab-panel active\" id=\"panel_#{kind2}\">")
      out = out.sub("let currentTabId = 'cai_dat';", "let currentTabId = '#{kind2}';")
      return out.sub("var SOLO_TAB = '';", "var SOLO_TAB = '#{kind2}';")
    end
    out = strip_tabs(out, KSU::Settings::TOOL_WINDOWS)
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
