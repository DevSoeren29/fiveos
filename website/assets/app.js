// FiveOS website: tabs, release info from GitHub, copy buttons.
(function () {
	'use strict';

	var config = window.FIVEOS_CONFIG || {};
	var $ = function (id) { return document.getElementById(id); };
	var all = function (sel) { return Array.prototype.slice.call(document.querySelectorAll(sel)); };

	// --- tabs ---------------------------------------------------------------

	function showTab(name) {
		if (!$('tab-' + name)) name = 'overview';
		all('.tab').forEach(function (t) {
			var on = t.dataset.tab === name;
			t.classList.toggle('active', on);
			t.setAttribute('aria-selected', on);
		});
		all('.panel').forEach(function (p) {
			p.classList.toggle('active', p.id === 'tab-' + name);
		});
		all('.menu-item[data-tab-link]').forEach(function (a) {
			a.classList.toggle('active', a.dataset.tabLink === name);
		});
		$('crumb-current').textContent = $('tab-' + name).dataset.title;
	}

	document.addEventListener('click', function (e) {
		var tab = e.target.closest('.tab');
		var link = e.target.closest('[data-tab-link]');
		var name = tab ? tab.dataset.tab : link ? link.dataset.tabLink : null;
		if (!name) return;
		e.preventDefault();
		showTab(name);
		history.replaceState(null, '', '#' + name);
		if (link && !tab) document.querySelector('.tabs').scrollIntoView({ behavior: 'smooth', block: 'start' });
	});

	window.addEventListener('hashchange', function () {
		showTab(location.hash.slice(1) || 'overview');
	});

	// --- release info -----------------------------------------------------------

	// owner.github.io/name -> owner/name
	function detectRepo() {
		if (config.repo) return config.repo;
		var host = location.hostname;
		var path = location.pathname.split('/').filter(Boolean);
		if (/\.github\.io$/.test(host) && path.length) return host.split('.')[0] + '/' + path[0];
		return '';
	}

	function formatSize(bytes) {
		return bytes >= 1e9 ? (bytes / 1e9).toFixed(1) + ' GB' : Math.round(bytes / 1e6) + ' MB';
	}

	function formatDate(iso) {
		return new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
	}

	function setVersion(v) {
		v = String(v).replace(/^v/, '');
		all('.release-version').forEach(function (e) { e.textContent = 'v' + v; });
		all('.release-version-plain').forEach(function (e) { e.textContent = v; });
	}

	// no repository/release: point the download buttons to the build instructions
	function noRelease(repo) {
		all('a.download-link').forEach(function (a) {
			if (a.closest('.steps')) {
				a.href = repo ? 'https://github.com/' + repo + '#building-the-iso' : '#';
				a.querySelector('.download-label').textContent = repo ? 'Build from source' : 'Coming soon';
				if (!repo) a.classList.add('disabled');
			}
		});
	}

	// config.downloadsPaused: no ISO links anywhere, notice at the top
	function pauseDownloads() {
		var notice = $('download-notice');
		notice.querySelector('span').textContent = config.pausedMessage || 'Downloads are paused.';
		notice.hidden = false;
		all('a.download-link').forEach(function (a) {
			a.removeAttribute('href');
			a.removeAttribute('data-tab-link');
			a.classList.add('disabled');
			a.setAttribute('aria-disabled', 'true');
			var label = a.querySelector('.download-label') || a.querySelector('span');
			if (label) label.textContent = 'Download paused';
		});
		all('.checksum-link').forEach(function (a) { a.hidden = true; });
	}

	function showRepoLinks(repo) {
		var url = 'https://github.com/' + repo;
		all('.repo-link').forEach(function (a) {
			a.href = url;
			a.hidden = false;
		});
		all('.repo-releases').forEach(function (a) {
			a.href = url + '/releases';
			a.hidden = false;
		});
	}

	function renderReleases(repo, releases) {
		var list = $('release-list');
		list.textContent = '';
		releases.slice(0, 3).forEach(function (r) {
			var li = document.createElement('li');
			var img = document.createElement('img');
			img.className = 'avatar logo-avatar';
			img.src = 'assets/mark-dark.png';
			img.alt = '';
			var info = document.createElement('div');
			// while paused, no links to the release pages (they offer the ISO)
			var a = document.createElement(config.downloadsPaused ? 'b' : 'a');
			if (!config.downloadsPaused) a.href = r.html_url;
			a.textContent = 'FiveOS ' + r.tag_name;
			var small = document.createElement('small');
			small.textContent = formatDate(r.published_at) + (r.prerelease ? ' · pre-release' : '');
			info.append(a, small);
			li.append(img, info);
			list.appendChild(li);
		});
		$('release-empty').hidden = releases.length > 0;
	}

	function applyLatest(release) {
		var iso = (release.assets || []).filter(function (a) { return /\.iso$/.test(a.name); })[0];
		var sum = (release.assets || []).filter(function (a) { return /\.iso\.sha256$/.test(a.name); })[0];
		setVersion(release.tag_name);
		$('release-date').textContent = formatDate(release.published_at);
		if (iso) $('release-size').textContent = formatSize(iso.size);
		if (config.downloadsPaused) return;
		if (iso) {
			all('a.download-link').forEach(function (a) {
				a.href = iso.browser_download_url;
				a.removeAttribute('data-tab-link');
			});
		}
		if (sum) {
			all('.checksum-link').forEach(function (a) {
				a.href = sum.browser_download_url;
				a.hidden = false;
			});
		}
	}

	function loadReleases() {
		var repo = detectRepo();
		if (config.version) setVersion(config.version);
		if (config.downloadsPaused) pauseDownloads();
		if (!repo) {
			if (!config.downloadsPaused) noRelease('');
			return;
		}
		showRepoLinks(repo);
		fetch('https://api.github.com/repos/' + repo + '/releases?per_page=5')
			.then(function (r) {
				if (!r.ok) throw new Error(r.status);
				return r.json();
			})
			.then(function (releases) {
				releases = releases.filter(function (r) { return !r.draft; });
				renderReleases(repo, releases);
				var stable = releases.filter(function (r) { return !r.prerelease; })[0] || releases[0];
				if (stable) applyLatest(stable);
				else if (!config.downloadsPaused) noRelease(repo);
			})
			.catch(function () {
				if (!config.downloadsPaused) noRelease(repo);
			});
	}

	// --- copy buttons -------------------------------------------------------

	function fallbackCopy(text) {
		var ta = document.createElement('textarea');
		ta.value = text;
		ta.setAttribute('readonly', '');
		ta.style.position = 'fixed';
		ta.style.opacity = '0';
		document.body.appendChild(ta);
		ta.select();
		try { document.execCommand('copy'); } catch (e) { /* ignore */ }
		document.body.removeChild(ta);
	}

	document.addEventListener('click', function (e) {
		var btn = e.target.closest('.copy-btn');
		if (!btn) return;
		var code = btn.parentElement.querySelector('code');
		if (!code) return;
		var text = code.textContent;
		var done = function () {
			btn.textContent = 'Copied';
			btn.classList.add('done');
			setTimeout(function () {
				btn.textContent = 'Copy';
				btn.classList.remove('done');
			}, 1500);
		};
		if (navigator.clipboard && window.isSecureContext) {
			navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text); done(); });
		} else {
			fallbackCopy(text);
			done();
		}
	});

	// --- start --------------------------------------------------------------

	showTab(location.hash.slice(1) || 'overview');
	loadReleases();
})();
