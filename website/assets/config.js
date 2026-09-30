// FiveOS website settings.
//
// repo:            GitHub repository as "owner/name". Enables the download
//                  buttons and loads version, date and size of the latest
//                  release from GitHub. Leave empty on GitHub Pages
//                  (owner.github.io/name) - it is detected automatically there.
// version:         shown until release information is available.
// downloadsPaused: true disables all download buttons on the website, e.g.
//                  while a release has known bugs.
// pausedMessage:   the notice shown at the top while downloads are paused.
window.FIVEOS_CONFIG = {
	repo: '',
	version: '0.1.0',
	downloadsPaused: false,
	pausedMessage: 'Downloads are paused while we fix a few bugs. Please check back soon.'
};
