/** Ink pill confirmation. Consumer positions it (top, 12px inset); auto-dismiss ~3s. */
export interface ToastProps {
  message: React.ReactNode;
  variant?: 'default' | 'success' | 'danger' | 'streak' | 'friend';
  icon?: string;
  action?: { label: string; onClick?: () => void };
  style?: React.CSSProperties;
}
export declare function Toast(props: ToastProps): JSX.Element;
