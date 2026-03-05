/**
 * Protocol Architecture SVG — Animated diagram showing Intuition Protocol
 * operations connected to a central node via stroke-dashoffset path animation
 * and traveling light dots via <animateMotion>.
 */
export function initProtocolDiagram(containerEl) {
  const isReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const operations = [
    'Create Atoms',
    'Build Triples',
    'Batch Ops',
    'Query State',
    'Bonding Curves',
    'Gas Estimation',
  ];

  const svgNS = 'http://www.w3.org/2000/svg';
  const W = 700;
  const H = 360;
  const CX = W / 2;
  const CY = H / 2;
  const RADIUS = 140;

  const svg = document.createElementNS(svgNS, 'svg');
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.setAttribute('width', '100%');
  svg.setAttribute('height', '100%');
  svg.style.maxWidth = '700px';
  svg.style.margin = '0 auto';
  svg.style.display = 'block';

  // Glow filter
  const defs = document.createElementNS(svgNS, 'defs');
  defs.innerHTML = `
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="3" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  `;
  svg.appendChild(defs);

  // Central node
  const centerGroup = document.createElementNS(svgNS, 'g');

  // Pulsing ring
  const pulseCircle = document.createElementNS(svgNS, 'circle');
  pulseCircle.setAttribute('cx', CX);
  pulseCircle.setAttribute('cy', CY);
  pulseCircle.setAttribute('r', 38);
  pulseCircle.setAttribute('fill', 'none');
  pulseCircle.setAttribute('stroke', '#007AFF');
  pulseCircle.setAttribute('stroke-width', '1');
  pulseCircle.setAttribute('opacity', '0.3');
  if (!isReduced) {
    pulseCircle.innerHTML = `<animate attributeName="r" values="38;48;38" dur="3s" repeatCount="indefinite"/>
      <animate attributeName="opacity" values="0.3;0.1;0.3" dur="3s" repeatCount="indefinite"/>`;
  }
  centerGroup.appendChild(pulseCircle);

  // Main circle
  const mainCircle = document.createElementNS(svgNS, 'circle');
  mainCircle.setAttribute('cx', CX);
  mainCircle.setAttribute('cy', CY);
  mainCircle.setAttribute('r', 32);
  mainCircle.setAttribute('fill', '#141414');
  mainCircle.setAttribute('stroke', '#007AFF');
  mainCircle.setAttribute('stroke-width', '1.5');
  mainCircle.setAttribute('filter', 'url(#glow)');
  centerGroup.appendChild(mainCircle);

  // Center label
  const centerText1 = document.createElementNS(svgNS, 'text');
  centerText1.setAttribute('x', CX);
  centerText1.setAttribute('y', CY - 4);
  centerText1.setAttribute('text-anchor', 'middle');
  centerText1.setAttribute('fill', '#fff');
  centerText1.setAttribute('font-size', '9');
  centerText1.setAttribute('font-family', 'Inter, system-ui, sans-serif');
  centerText1.setAttribute('font-weight', '600');
  centerText1.textContent = 'Intuition';
  centerGroup.appendChild(centerText1);

  const centerText2 = document.createElementNS(svgNS, 'text');
  centerText2.setAttribute('x', CX);
  centerText2.setAttribute('y', CY + 10);
  centerText2.setAttribute('text-anchor', 'middle');
  centerText2.setAttribute('fill', '#007AFF');
  centerText2.setAttribute('font-size', '8');
  centerText2.setAttribute('font-family', 'Inter, system-ui, sans-serif');
  centerText2.setAttribute('font-weight', '500');
  centerText2.textContent = 'Protocol';
  centerGroup.appendChild(centerText2);

  // Operation nodes
  operations.forEach((op, i) => {
    const angle = (Math.PI * 2 * i) / operations.length - Math.PI / 2;
    const nx = CX + Math.cos(angle) * RADIUS;
    const ny = CY + Math.sin(angle) * RADIUS;

    // Connection line
    const path = document.createElementNS(svgNS, 'path');
    const d = `M${CX},${CY} L${nx},${ny}`;
    path.setAttribute('d', d);
    path.setAttribute('stroke', '#242424');
    path.setAttribute('stroke-width', '1');
    path.setAttribute('fill', 'none');

    if (!isReduced) {
      const len = Math.sqrt((nx - CX) ** 2 + (ny - CY) ** 2);
      path.setAttribute('stroke-dasharray', len);
      path.setAttribute('stroke-dashoffset', len);
      path.style.animation = `dash-draw 1s ease-out ${0.3 + i * 0.15}s forwards`;
    }
    svg.appendChild(path);

    // Traveling light dot
    if (!isReduced) {
      const dot = document.createElementNS(svgNS, 'circle');
      dot.setAttribute('r', '2');
      dot.setAttribute('fill', '#007AFF');
      dot.setAttribute('filter', 'url(#glow)');
      dot.innerHTML = `<animateMotion dur="${2 + i * 0.3}s" repeatCount="indefinite" begin="${1 + i * 0.2}s" path="${d}"/>`;
      svg.appendChild(dot);
    }

    // Node circle
    const nodeCircle = document.createElementNS(svgNS, 'circle');
    nodeCircle.setAttribute('cx', nx);
    nodeCircle.setAttribute('cy', ny);
    nodeCircle.setAttribute('r', 24);
    nodeCircle.setAttribute('fill', '#0a0a0a');
    nodeCircle.setAttribute('stroke', '#242424');
    nodeCircle.setAttribute('stroke-width', '1');
    svg.appendChild(nodeCircle);

    // Node text
    const text = document.createElementNS(svgNS, 'text');
    text.setAttribute('x', nx);
    text.setAttribute('y', ny + 1);
    text.setAttribute('text-anchor', 'middle');
    text.setAttribute('dominant-baseline', 'middle');
    text.setAttribute('fill', '#a8a8a8');
    text.setAttribute('font-size', '8');
    text.setAttribute('font-family', 'Inter, system-ui, sans-serif');
    text.setAttribute('font-weight', '500');
    // Split long names
    if (op.length > 10) {
      const words = op.split(' ');
      const mid = Math.ceil(words.length / 2);
      text.setAttribute('y', ny - 4);
      text.textContent = words.slice(0, mid).join(' ');
      const text2 = document.createElementNS(svgNS, 'text');
      text2.setAttribute('x', nx);
      text2.setAttribute('y', ny + 7);
      text2.setAttribute('text-anchor', 'middle');
      text2.setAttribute('dominant-baseline', 'middle');
      text2.setAttribute('fill', '#a8a8a8');
      text2.setAttribute('font-size', '8');
      text2.setAttribute('font-family', 'Inter, system-ui, sans-serif');
      text2.setAttribute('font-weight', '500');
      text2.textContent = words.slice(mid).join(' ');
      svg.appendChild(text2);
    } else {
      text.textContent = op;
    }
    svg.appendChild(text);
  });

  // Append center group last so it renders on top
  svg.appendChild(centerGroup);

  containerEl.insertBefore(svg, containerEl.firstChild);
}
