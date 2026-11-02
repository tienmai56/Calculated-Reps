/** Single radio option. Compose several sharing state for a group. */
export interface RadioProps {
  checked?: boolean;
  /** Called with this radio's value */
  onChange?: (value: string) => void;
  value?: string;
  name?: string;
  label?: string;
  description?: string;
  disabled?: boolean;
  style?: React.CSSProperties;
}
export declare function Radio(props: RadioProps): JSX.Element;
