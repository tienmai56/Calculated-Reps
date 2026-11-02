/** In-screen switcher. segmented (default) = pill track with white thumb; underline = text tabs with a short coral bar. */
export interface TabItem { id: string; label: string; count?: number | string; }
export interface TabsProps {
  items: Array<TabItem | string>;
  value?: string;
  onChange?: (id: string) => void;
  variant?: 'segmented' | 'underline';
  style?: React.CSSProperties;
}
export declare function Tabs(props: TabsProps): JSX.Element;
