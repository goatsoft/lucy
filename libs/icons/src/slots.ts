/**
 * The icons Lucy's own components draw, and the icon that fills each. This is
 * the one list: every build writes these names into its module (unless the
 * config says `"lucy": false`), and Lucy's Icon reads the slots from its own
 * sheet, which is built from this list too.
 */
export const LUCY_SLOTS: Readonly<Record<string, string>> = {
  'lucy:close': 'lucide:x',
  'lucy:check': 'lucide:check',
  'lucy:chevron-down': 'lucide:chevron-down',
  'lucy:chevron-up': 'lucide:chevron-up',
  'lucy:chevron-left': 'lucide:chevron-left',
  'lucy:chevron-right': 'lucide:chevron-right',
  'lucy:minus': 'lucide:minus',
  'lucy:plus': 'lucide:plus',
}
