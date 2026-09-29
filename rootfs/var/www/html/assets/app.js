// FiveOS landing page: tabs, live server status (api/status.php), copy buttons.
(function () {
	'use strict';

	var REFRESH_MS = 15000;
	var SORTS = ['id', 'name', 'ping'];
	var SORT_LABELS = { id: 'ID', name: 'Name', ping: 'Ping' };
	var sortBy = 'id';
	var lastPlayers = [];

	var $ = function (id) { return document.getElementById(id); };

	function el(tag, className, text) {
		var e = document.createElement(tag);
		if (className) e.className = className;
		if (text != null) e.textContent = text;
		return e;
	}

	// --- tabs ---------------------------------------------------------------

	function showTab(name) {
		if (!$('tab-' + name)) name = 'overview';
		document.querySelectorAll('.tab').forEach(function (t) {
			var on = t.dataset.tab === name;
			t.classList.toggle('active', on);
			t.setAttribute('aria-selected', on);
		});
		document.querySelectorAll('.panel').forEach(function (p) {
			p.classList.toggle('active', p.id === 'tab-' + name);
		});
		document.querySelectorAll('.menu-item[data-tab-link]').forEach(function (a) {
			a.classList.toggle('active', a.dataset.tabLink === name);
		});
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

	// --- players ------------------------------------------------------------

	function initials(name) {
		var parts = (name || '?').replace(/[^\p{L}\p{N} ]/gu, ' ').trim().split(/\s+/);
		var s = parts.length > 1 ? parts[0][0] + parts[1][0] : (parts[0] || '?').slice(0, 2);
		return s.toUpperCase();
	}

	function avatar(name) {
		var h = 0;
		for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 360;
		var a = el('span', 'avatar', initials(name));
		a.style.background = 'hsl(' + h + ' 45% 45%)';
		a.setAttribute('aria-hidden', 'true');
		return a;
	}

	function pingClass(ping) {
		return ping < 80 ? 'good' : ping < 150 ? 'ok' : 'bad';
	}

	function sorted(players) {
		return players.slice().sort(function (a, b) {
			if (sortBy === 'name') return a.name.localeCompare(b.name);
			if (sortBy === 'ping') return a.ping - b.ping;
			return a.id - b.id;
		});
	}

	function renderPlayers(players) {
		lastPlayers = players;
		var grid = $('player-grid');
		var side = $('sidebar-players');
		grid.textContent = '';
		side.textContent = '';

		sorted(players).forEach(function (p) {
			var name = p.name || 'Unknown';
			var card = el('article', 'entry');
			var body = el('div', 'entry-body');
			body.append(el('div', 'entry-category', 'Player'), el('h3', 'entry-title', name));
			var footer = el('div', 'entry-footer');
			var author = el('div', 'author');
			var info = el('div');
			info.append(el('b', null, 'ID ' + p.id), el('small', null, 'Online'));
			author.append(avatar(name), info);
			var ping = el('span', 'meta ping ' + pingClass(p.ping));
			ping.innerHTML = '<svg class="icon"><use href="#i-signal"/></svg>';
			ping.append('Ping: ' + p.ping + ' ms');
			footer.append(author, ping);
			card.append(body, footer);
			grid.appendChild(card);
		});

		players.slice(0, 5).forEach(function (p) {
			var name = p.name || 'Unknown';
			var li = el('li');
			var info = el('div');
			info.append(el('b', null, name), el('small', null, 'ID ' + p.id + ' · ' + p.ping + ' ms'));
			li.append(avatar(name), info);
			side.appendChild(li);
		});

		$('player-empty').hidden = players.length > 0;
		$('sidebar-empty').hidden = players.length > 0;
		$('players-count').textContent = players.length;
	}

	$('sort-btn').addEventListener('click', function () {
		sortBy = SORTS[(SORTS.indexOf(sortBy) + 1) % SORTS.length];
		this.querySelector('span').textContent = 'Sort: ' + SORT_LABELS[sortBy];
		renderPlayers(lastPlayers);
	});

	// --- status -------------------------------------------------------------

	function setConnect(host, port) {
		var addr = host + ':' + port;
		$('connect-cmd').textContent = 'connect ' + addr;
		$('connect-cmd-2').textContent = 'connect ' + addr;
		$('connect-link').href = 'fivem://connect/' + addr;
	}

	function setStatus(state, text) {
		$('status-pill').className = 'status' + (state ? ' ' + state : '');
		$('status-text').textContent = text;
	}

	function render(s) {
		setConnect(s.host || location.hostname, s.port || 30120);
		if (s.fiveos) $('fiveos-version').textContent = 'v' + s.fiveos;
		$('stat-build').textContent = s.build || '–';

		if (!s.online) {
			setStatus('offline', 'Offline');
			$('stat-players').textContent = '0';
			$('stat-max').textContent = '';
			$('stat-bar').style.width = '0';
			$('stat-resources').textContent = '–';
			$('stat-onesync').textContent = '–';
			$('player-empty').textContent = 'The server is offline.';
			renderPlayers([]);
			return;
		}

		setStatus('online', 'Online · ' + s.clients + (s.maxClients ? '/' + s.maxClients : '') + ' players');
		if (s.hostname) {
			$('server-name').textContent = s.hostname;
			document.title = s.hostname + ' - FiveOS';
		}
		$('stat-players').textContent = s.clients;
		$('stat-max').textContent = s.maxClients ? ' / ' + s.maxClients : '';
		$('stat-bar').style.width = s.maxClients ? Math.min(100, (s.clients / s.maxClients) * 100) + '%' : '0';
		$('stat-resources').textContent = s.resources == null ? '–' : s.resources;
		$('stat-onesync').textContent = s.onesync == null ? '–' : (s.onesync ? 'On' : 'Off');
		$('player-empty').textContent = 'No players online.';
		renderPlayers(s.players || []);
	}

	function load() {
		fetch('api/status.php', { cache: 'no-store' })
			.then(function (r) {
				if (!r.ok) throw new Error(r.status);
				return r.json();
			})
			.then(render)
			.catch(function () {
				setStatus('', 'Status unavailable');
				setConnect(location.hostname || 'server-ip', 30120);
			});
	}

	// --- copy buttons -------------------------------------------------------

	// the page is usually served over plain http, where navigator.clipboard is unavailable
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

	function copyText(text, btn) {
		var label = btn.querySelector('span') || btn;
		var done = function () {
			label.textContent = 'Copied';
			btn.classList.add('done');
			setTimeout(function () {
				label.textContent = 'Copy';
				btn.classList.remove('done');
			}, 1500);
		};
		if (navigator.clipboard && window.isSecureContext) {
			navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text); done(); });
		} else {
			fallbackCopy(text);
			done();
		}
	}

	document.addEventListener('click', function (e) {
		var btn = e.target.closest('.copy-btn');
		if (!btn) return;
		var src = btn.dataset.copyFrom ? $(btn.dataset.copyFrom) : btn.parentElement.querySelector('code');
		if (src) copyText(src.textContent, btn);
	});

	// --- start --------------------------------------------------------------

	showTab(location.hash.slice(1) || 'overview');
	window.addEventListener('hashchange', function () {
		showTab(location.hash.slice(1) || 'overview');
	});
	load();
	setInterval(function () {
		if (!document.hidden) load();
	}, REFRESH_MS);
})();
