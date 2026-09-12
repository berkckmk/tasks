import test from 'node:test';
import assert from 'node:assert/strict';
import { modalMotion } from './modal-motion.ts';

test('modalMotion token values meet UX motion specifications', () => {
  // Target backdrop tint is within rgba(15, 15, 15, 0.24 - 0.30)
  assert.equal(modalMotion.backdropColor, 'rgba(15, 15, 15, 0.27)');

  // Backdrop durations
  assert.ok(modalMotion.backdropOpenDuration >= 180 && modalMotion.backdropOpenDuration <= 220);
  assert.ok(modalMotion.backdropCloseDuration >= 150 && modalMotion.backdropCloseDuration <= 200);

  // Sheet translateY is natural short slide (40-60px range)
  assert.ok(modalMotion.sheetTranslateY >= 40 && modalMotion.sheetTranslateY <= 60);

  // Spring damping in 22-26 range
  assert.ok(modalMotion.springDamping >= 22 && modalMotion.springDamping <= 26);

  // Spring stiffness in 220-280 range
  assert.ok(modalMotion.springStiffness >= 220 && modalMotion.springStiffness <= 280);

  // Dialog scale and translateY
  assert.equal(modalMotion.dialogScale, 0.96);
  assert.equal(modalMotion.dialogTranslateY, 8);
});
