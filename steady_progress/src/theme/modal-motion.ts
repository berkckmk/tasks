/**
 * Unified modal, sheet, and dialog motion constants.
 * Adheres to controlled spring parameters and subtle backdrop fades.
 */
export const modalMotion = {
  /** Target backdrop tint (subtle focus without pitch-black darkening) */
  backdropColor: 'rgba(15, 15, 15, 0.27)',
  /** Smooth backdrop entrance duration (ms) */
  backdropOpenDuration: 200,
  /** Quick backdrop exit duration (ms) */
  backdropCloseDuration: 180,

  /** Natural short vertical slide distance for bottom sheets (40-60px range) */
  sheetTranslateY: 50,
  /** Low-bounce controlled spring damping */
  springDamping: 24,
  /** Responsive controlled spring stiffness */
  springStiffness: 250,

  /** Dialog / center modal initial scale */
  dialogScale: 0.96,
  /** Dialog / center modal initial vertical offset */
  dialogTranslateY: 8,
  /** Dialog entrance duration */
  dialogOpenDuration: 180,
  /** Dialog exit duration */
  dialogCloseDuration: 150,
} as const;
