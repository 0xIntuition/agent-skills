/**
 * Typing Terminal — Animates a command being typed character by character.
 */
export function initTypingTerminal(el, command, speed = 50) {
  const isReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (isReduced) {
    el.textContent = command;
    return;
  }

  el.textContent = '';
  el.classList.add('cursor-blink');
  let i = 0;

  function type() {
    if (i < command.length) {
      el.textContent = command.slice(0, i + 1);
      i++;
      setTimeout(type, speed + Math.random() * 30);
    } else {
      // Keep blinking cursor
    }
  }

  // Start after a short delay
  setTimeout(type, 800);
}
