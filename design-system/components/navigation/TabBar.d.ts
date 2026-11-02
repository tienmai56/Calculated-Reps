/**
 * Bottom app nav: Activity, Training, [+ Create training], Friends, Profile. White, blurred, 86px incl. home indicator.
 * @startingPoint section="Navigation" subtitle="Bottom tab bar + segmented tabs" viewport="700x300"
 */
export interface TabBarItem { id: string; icon: string; label: string; badge?: boolean; }
export interface TabBarProps {
  items: TabBarItem[];
  value?: string;
  onChange?: (id: string) => void;
  centerAction?: { icon?: string; label?: string; onClick?: () => void };
  style?: React.CSSProperties;
}
export declare function TabBar(props: TabBarProps): JSX.Element;
