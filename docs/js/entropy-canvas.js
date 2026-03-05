/**
 * Entropy Canvas — Order/chaos particle system for hero background.
 * Left side: structured grid (skills), Right side: chaotic motion (agent behavior).
 * Connected with lines when particles are near each other.
 */
const PARTICLE_COUNT_DESKTOP = 80;
const PARTICLE_COUNT_MOBILE = 35;
const CONNECTION_DISTANCE = 120;
const ACCENT = [0, 122, 255]; // #007AFF

export function initEntropyCanvas(canvasEl) {
  const ctx = canvasEl.getContext('2d');
  let particles = [];
  let width, height;
  let animId;
  let isReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = canvasEl.parentElement.clientWidth;
    height = canvasEl.parentElement.clientHeight;
    canvasEl.width = width * dpr;
    canvasEl.height = height * dpr;
    canvasEl.style.width = width + 'px';
    canvasEl.style.height = height + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function createParticles() {
    const count = width < 768 ? PARTICLE_COUNT_MOBILE : PARTICLE_COUNT_DESKTOP;
    particles = [];
    const midX = width / 2;

    for (let i = 0; i < count; i++) {
      const isLeft = i < count / 2;
      let x, y, vx, vy;

      if (isLeft) {
        // Ordered side — grid-ish placement with gentle drift
        const cols = Math.ceil(Math.sqrt(count / 2));
        const row = Math.floor((i) / cols);
        const col = (i) % cols;
        const spacing = Math.min(midX / (cols + 1), height / (cols + 1));
        x = (col + 1) * spacing + (Math.random() - 0.5) * 20;
        y = (row + 1) * spacing + 100 + (Math.random() - 0.5) * 20;
        vx = (Math.random() - 0.5) * 0.15;
        vy = (Math.random() - 0.5) * 0.15;
      } else {
        // Chaotic side — random placement with faster movement
        x = midX + Math.random() * midX;
        y = Math.random() * height;
        vx = (Math.random() - 0.5) * 0.8;
        vy = (Math.random() - 0.5) * 0.8;
      }

      particles.push({ x, y, vx, vy, baseX: x, baseY: y, isLeft, opacity: 0.2 + Math.random() * 0.5 });
    }
  }

  function draw() {
    ctx.clearRect(0, 0, width, height);

    // Draw connections
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const dx = particles[i].x - particles[j].x;
        const dy = particles[i].y - particles[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < CONNECTION_DISTANCE) {
          const alpha = (1 - dist / CONNECTION_DISTANCE) * 0.15;
          ctx.strokeStyle = `rgba(${ACCENT[0]}, ${ACCENT[1]}, ${ACCENT[2]}, ${alpha})`;
          ctx.lineWidth = 0.5;
          ctx.beginPath();
          ctx.moveTo(particles[i].x, particles[i].y);
          ctx.lineTo(particles[j].x, particles[j].y);
          ctx.stroke();
        }
      }
    }

    // Draw particles
    for (const p of particles) {
      ctx.beginPath();
      ctx.arc(p.x, p.y, 1.5, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${ACCENT[0]}, ${ACCENT[1]}, ${ACCENT[2]}, ${p.opacity})`;
      ctx.fill();
    }
  }

  function update() {
    for (const p of particles) {
      p.x += p.vx;
      p.y += p.vy;

      if (p.isLeft) {
        // Gentle return to base position
        p.vx += (p.baseX - p.x) * 0.001;
        p.vy += (p.baseY - p.y) * 0.001;
        // Damping
        p.vx *= 0.99;
        p.vy *= 0.99;
      } else {
        // Bounce off edges on right side
        if (p.x < width / 2 || p.x > width) p.vx *= -1;
        if (p.y < 0 || p.y > height) p.vy *= -1;
        // Keep in bounds
        p.x = Math.max(width / 2, Math.min(width, p.x));
        p.y = Math.max(0, Math.min(height, p.y));
      }
    }
  }

  let lastTime = 0;
  function loop(time) {
    // Frame skip for low-end devices
    if (time - lastTime < 16) {
      animId = requestAnimationFrame(loop);
      return;
    }
    lastTime = time;
    update();
    draw();
    animId = requestAnimationFrame(loop);
  }

  function init() {
    resize();
    createParticles();

    if (isReduced) {
      // Static render for reduced motion
      draw();
      return;
    }

    animId = requestAnimationFrame(loop);
  }

  window.addEventListener('resize', () => {
    resize();
    createParticles();
  });

  init();

  return () => {
    if (animId) cancelAnimationFrame(animId);
  };
}
