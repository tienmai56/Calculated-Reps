/** Round icon-only control for headers, post actions, photo overlays. */
export interface IconButtonProps {
  icon: string;
  variant?: 'ghost' | 'filled' | 'accent' | 'overlay' | 'inverse';
  /** Diameter px, default 44 */
  size?: number;
  iconSize?: number;
  active?: boolean;
  /** Fill glyph when active (heart) */
  filledWhenActive?: boolean;
  /** CSS color for the active glyph, default coral */
  activeColor?: string;
  /** true = dot; number = count */
  badge?: boolean | number | string;
  label?: string;
  disabled?: boolean;
  onClick?: (e: any) => void;
  style?: React.CSSProperties;
}
export declare function IconButton(props: IconButtonProps): JSX.Element;
