/** Small soft pill for status: "Organizer", "Pending", "Completed", "8 wk streak". */
export interface BadgeProps {
  variant?: 'neutral' | 'accent' | 'soft' | 'success' | 'warning' | 'danger' | 'info' | 'flame';
  dot?: boolean;
  /** Optional leading node, e.g. <Icon name="flame" size={12} /> */
  icon?: React.ReactNode;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export declare function Badge(props: BadgeProps): JSX.Element;
