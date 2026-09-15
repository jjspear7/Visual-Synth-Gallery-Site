(() => {
  const items = Array.isArray(window.GALLERY_ITEMS) ? window.GALLERY_ITEMS : [];
  const gallery = document.querySelector('#gallery');
  const count = document.querySelector('#piece-count');
  const empty = document.querySelector('#empty-state');
  const viewer = document.querySelector('#viewer');
  const viewerVideo = document.querySelector('#viewer-video');
  const viewerCaption = document.querySelector('#viewer-caption');
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let currentIndex = 0;

  count.textContent = `${items.length} ${items.length === 1 ? 'piece' : 'pieces'}`;
  empty.hidden = items.length > 0;

  const setGridVideoSource = (video) => {
    if (video.src || !video.dataset.src) return;
    video.src = video.dataset.src;
    video.load();
  };

  const cards = items.map((item, index) => {
    const button = document.createElement('button');
    const image = document.createElement('img');
    const video = document.createElement('video');
    const label = document.createElement('span');

    button.className = 'piece';
    button.type = 'button';
    button.dataset.index = index;
    button.setAttribute('aria-label', `Open ${item.title}`);

    image.src = item.poster;
    image.alt = '';
    image.loading = index < 9 ? 'eager' : 'lazy';
    image.decoding = 'async';

    video.dataset.src = item.video;
    video.muted = true;
    video.loop = true;
    video.playsInline = true;
    video.preload = 'none';
    video.poster = item.poster;
    video.addEventListener('canplay', () => button.classList.add('is-ready'), { once: true });

    label.className = 'piece-title';
    label.textContent = item.title;

    button.append(image, video, label);
    button.addEventListener('click', () => openViewer(index));
    gallery.append(button);
    return { button, video };
  });

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      const record = cards[Number(entry.target.dataset.index)];
      if (!record) return;

      if (entry.isIntersecting) {
        setGridVideoSource(record.video);
        if (!prefersReducedMotion) record.video.play().catch(() => {});
      } else {
        record.video.pause();
      }
    });
  }, { rootMargin: '45% 0px', threshold: 0.01 });

  cards.forEach(({ button }) => observer.observe(button));

  function showViewerItem(index) {
    currentIndex = (index + items.length) % items.length;
    const item = items[currentIndex];
    viewerVideo.pause();
    viewerVideo.poster = item.poster;
    viewerVideo.src = item.video;
    viewerCaption.textContent = item.title;
    viewerVideo.load();
    viewerVideo.play().catch(() => {});
  }

  function openViewer(index) {
    if (!items.length) return;
    showViewerItem(index);
    if (!viewer.open) viewer.showModal();
  }

  function closeViewer() {
    viewerVideo.pause();
    viewerVideo.removeAttribute('src');
    viewerVideo.load();
    viewer.close();
  }

  document.querySelector('#viewer-close').addEventListener('click', closeViewer);
  document.querySelector('#viewer-prev').addEventListener('click', () => showViewerItem(currentIndex - 1));
  document.querySelector('#viewer-next').addEventListener('click', () => showViewerItem(currentIndex + 1));

  viewer.addEventListener('click', (event) => {
    if (event.target === viewer) closeViewer();
  });

  viewer.addEventListener('cancel', (event) => {
    event.preventDefault();
    closeViewer();
  });

  document.addEventListener('keydown', (event) => {
    if (!viewer.open) return;
    if (event.key === 'ArrowLeft') showViewerItem(currentIndex - 1);
    if (event.key === 'ArrowRight') showViewerItem(currentIndex + 1);
  });
})();
