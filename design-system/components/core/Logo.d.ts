/** The Silverback logo: mark, one-color mark, app-icon tile, and lockups with the "grip gorillas." wordmark. */
export interface LogoProps {
  /**
   * mark: default (coral brow) on paper / white / sun ·
   * mono: ink brow, on coral or 1-color ·
   * appIcon: mark on a sun tile, also the logo on ink and photos ·
   * lockup: mark + wordmark on light grounds ·
   * lockupInverse: app-icon tile + paper wordmark on ink
   */
  variant?: 'mark' | 'mono' | 'appIcon' | 'lockup' | 'lockupInverse';
  /** Mark height (or tile side) in px, default 40. Minimum 24 for the mark. */
  size?: number;
  /** Accessible name, default "Grip Gorillas" */
  label?: string;
  style?: React.CSSProperties;
}
export declare function Logo(props: LogoProps): JSX.Element;
