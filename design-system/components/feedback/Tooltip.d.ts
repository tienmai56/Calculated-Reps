/** Hover hint — ink chip. */
export interface TooltipProps {
  content: React.ReactNode;
  children: React.ReactNode;
  placement?: 'top' | 'bottom';
  open?: boolean;
  style?: React.CSSProperties;
}
export declare function Tooltip(props: TooltipProps): JSX.Element;
