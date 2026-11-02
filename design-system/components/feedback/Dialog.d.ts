/** Overlay surface. sheet = bottom sheet (default on mobile); modal = centered confirm. */
export interface DialogProps {
  open?: boolean;
  onClose?: () => void;
  title?: string;
  description?: string;
  children?: React.ReactNode;
  /** Buttons row, laid out with 8px gap */
  actions?: React.ReactNode;
  variant?: 'sheet' | 'modal';
  /** Position absolute within nearest positioned parent (e.g. a phone frame) instead of fixed */
  contained?: boolean;
  style?: React.CSSProperties;
}
export declare function Dialog(props: DialogProps): JSX.Element | null;
