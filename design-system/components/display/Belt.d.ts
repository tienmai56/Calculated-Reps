/**
 * Belt rank bar — the Grip Gorillas signature graphic. Rank color, black (or red) rank bar, 0–4 tape stripes.
 */
export interface BeltProps {
  rank?: 'white' | 'blue' | 'purple' | 'brown' | 'black' | 'coral' | 'red' | 'grey' | 'yellow' | 'orange' | 'green';
  /** 0–4 */
  stripes?: number;
  /** xs 6px · sm 10px · md 16px · lg 24px tall */
  size?: 'xs' | 'sm' | 'md' | 'lg';
  /** CSS width; default 100% */
  width?: number | string;
  /** Show "Purple belt · 2 stripes" overline under the bar */
  label?: boolean;
  style?: React.CSSProperties;
}
export declare function Belt(props: BeltProps): JSX.Element;
export declare const BELT_COLORS: Record<string, string>;
