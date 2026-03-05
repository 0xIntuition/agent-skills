/**
 * Main — Scroll observer, copy-to-clipboard, glow card mouse tracking.
 */
import { initEntropyCanvas } from './entropy-canvas.js';
import { initSparkles } from './sparkles.js';
import { initProtocolDiagram } from './protocol-diagram.js';

// ── Scroll Reveal ──
function initReveal() {
  const els = document.querySelectorAll('.reveal');
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.1, rootMargin: '0px 0px -40px 0px' }
  );
  els.forEach((el) => observer.observe(el));
}

// ── Glow Card Mouse Tracking ──
function initGlowCards() {
  document.addEventListener('mousemove', (e) => {
    const cards = document.querySelectorAll('.glow-card');
    cards.forEach((card) => {
      const rect = card.getBoundingClientRect();
      card.style.setProperty('--mouse-x', `${e.clientX - rect.left}px`);
      card.style.setProperty('--mouse-y', `${e.clientY - rect.top}px`);
    });
  });
}

// ── Copy to Clipboard ──
function initCopyButtons() {
  document.querySelectorAll('[data-copy]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const text = btn.getAttribute('data-copy');
      try {
        await navigator.clipboard.writeText(text);
        const icon = btn.querySelector('svg');
        const originalHTML = icon.outerHTML;
        icon.outerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`;
        setTimeout(() => {
          btn.querySelector('svg').outerHTML = originalHTML;
        }, 2000);
      } catch {
        // Fallback: noop
      }
    });
  });
}

// ── Init all ──
document.addEventListener('DOMContentLoaded', () => {
  initReveal();
  initGlowCards();
  initCopyButtons();

  // Entropy canvas
  const canvas = document.getElementById('entropy-canvas');
  if (canvas) initEntropyCanvas(canvas);

  // Sparkles
  document.querySelectorAll('[data-sparkles]').forEach((el) => {
    initSparkles(el, 10);
  });

  // Protocol diagram
  const diagramEl = document.getElementById('protocol-diagram');
  if (diagramEl) {
    const diagramObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          initProtocolDiagram(diagramEl);
          diagramObserver.disconnect();
        }
      },
      { threshold: 0.2 }
    );
    diagramObserver.observe(diagramEl);
  }
});
