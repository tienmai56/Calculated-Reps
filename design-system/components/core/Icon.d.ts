/** Lucide icon (v0.454, 2px stroke). See ICON_NAMES for the bundled set (house, users, calendar-plus, qr-code, scan-line, flame, handshake, link, camera, image-plus …). */
export interface IconProps {
  name: string;
  size?: number;
  strokeWidth?: number;
  color?: string;
  filled?: boolean;
  style?: React.CSSProperties;
}
export declare function Icon(props: IconProps): JSX.Element | null;
export declare const ICON_NAMES: string[];
