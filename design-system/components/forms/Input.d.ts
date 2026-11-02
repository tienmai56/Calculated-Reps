/** Text field / textarea with label, hint, error and leading icon. */
export interface InputProps {
  label?: string;
  hint?: string;
  /** Error message — turns border red and replaces hint */
  error?: string;
  /** Leading icon name (Lucide) */
  iconLeft?: string;
  value?: string;
  defaultValue?: string;
  placeholder?: string;
  type?: string;
  multiline?: boolean;
  rows?: number;
  disabled?: boolean;
  onChange?: (e: any) => void;
  style?: React.CSSProperties;
  inputStyle?: React.CSSProperties;
}
export declare function Input(props: InputProps): JSX.Element;
