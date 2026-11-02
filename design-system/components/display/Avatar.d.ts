/** Round avatar: photo or initials on a friendly hue (derived from name). Optional belt-colored ring. */
export interface AvatarProps {
  src?: string;
  name?: string;
  /** px, default 40 */
  size?: number;
  /** Belt key (white, blue, purple…) or CSS color for the ring */
  belt?: string;
  /** Gap color between ring and photo; default app bg */
  ring?: string;
  online?: boolean;
  style?: React.CSSProperties;
}
export declare function Avatar(props: AvatarProps): JSX.Element;
