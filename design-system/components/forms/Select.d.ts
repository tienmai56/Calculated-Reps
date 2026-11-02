/** Native dropdown styled to match Input. */
export interface SelectOption { value: string; label: string; }
export interface SelectProps {
  label?: string;
  options: Array<string | SelectOption>;
  value?: string;
  defaultValue?: string;
  placeholder?: string;
  disabled?: boolean;
  onChange?: (e: any) => void;
  style?: React.CSSProperties;
}
export declare function Select(props: SelectProps): JSX.Element;
