/** White surface with soft shadow, 22px radius. sunken = paper-2 grouped background; outline = dashed-free 1.5px border. */
export interface CardProps {
  children?: React.ReactNode;
  padding?: number | string;
  variant?: 'default' | 'sunken' | 'outline';
  interactive?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export declare function Card(props: CardProps): JSX.Element;
