/** Pill-shaped action. Primary has a chunky "pressable" bottom edge that sinks on press. One primary per screen. */
export interface ButtonProps {
  /** primary = coral CTA; secondary = white outlined; soft = coral tint; ghost = text; inverse = ink; danger = red tint */
  variant?: 'primary' | 'secondary' | 'soft' | 'ghost' | 'inverse' | 'danger';
  /** sm 36 · md 48 (default) · lg 56 */
  size?: 'sm' | 'md' | 'lg';
  iconLeft?: string;
  iconRight?: string;
  fullWidth?: boolean;
  disabled?: boolean;
  type?: 'button' | 'submit' | 'reset';
  onClick?: (e: any) => void;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}
export declare function Button(props: ButtonProps): JSX.Element;
