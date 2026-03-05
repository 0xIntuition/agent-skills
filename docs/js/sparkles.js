/**
 * Sparkles — lightweight DOM-based twinkling dot accents.
 * Creates <span> elements with CSS sparkle-fade animation.
 */
export function initSparkles(containerEl, count = 8) {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const rect = containerEl.getBoundingClientRect();
  const existing = containerEl.querySelectorAll('.sparkle');
  existing.forEach(s => s.remove());

  for (let i = 0; i < count; i++) {
    const sparkle = document.createElement('span');
    sparkle.className = 'sparkle';
    sparkle.style.setProperty('--delay', `${Math.random() * 3}s`);
    sparkle.style.setProperty('--duration', `${1.5 + Math.random() * 2}s`);
    sparkle.style.left = `${Math.random() * 100}%`;
    sparkle.style.top = `${Math.random() * 100}%`;
    sparkle.style.width = `${2 + Math.random() * 3}px`;
    sparkle.style.height = sparkle.style.width;
    containerEl.appendChild(sparkle);
  }
}
