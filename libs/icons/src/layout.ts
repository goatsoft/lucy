/** How cells sit in square sheets. */
export interface Layout {
  size: number
  sheet: number
  padding: number
}

export interface Slot {
  /** 0-based sheet index */
  sheet: number
  /** top left of the cell, in pixels */
  x: number
  y: number
}

/** Cells per row (and per column) of a sheet. */
export function columns(layout: Layout): number {
  const stride = layout.size + layout.padding * 2
  return Math.max(1, Math.floor(layout.sheet / stride))
}

export function perSheet(layout: Layout): number {
  const n = columns(layout)
  return n * n
}

/** Where the cell at `index` goes. Cells fill a sheet row by row. */
export function slot(index: number, layout: Layout): Slot {
  const n = columns(layout)
  const per = n * n
  const stride = layout.size + layout.padding * 2
  const within = index % per
  return {
    sheet: Math.floor(index / per),
    x: (within % n) * stride + layout.padding,
    y: Math.floor(within / n) * stride + layout.padding,
  }
}

export function sameLayout(a: Layout, b: Layout): boolean {
  return a.size === b.size && a.sheet === b.sheet && a.padding === b.padding
}
