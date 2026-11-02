/** Pill chip — filters, technique tags, selectable options. Selected = Gi-white fill. */
export interface TagProps {
  children?: React.ReactNode;
  icon?: string;
  selected?: boolean;
  onClick?: () => void;
  /** Shows an × that calls this */
  onRemove?: () => void;
  size?: 'sm' | 'md';
  style?: React.CSSProperties;
}
export declare function Tag(props: TagProps): JSX.Element;
