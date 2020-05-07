import React from 'react';
import { useStore } from 'effector-react';
import { Alert, Button, Input, Text } from '@tarantool.io/ui-kit';
import { css } from 'emotion';
import { Formik, Form } from 'formik';
import { FormContainer, FieldConstructor } from '../FieldGroup'
import * as Yup from 'yup';
import usersStore from 'src/store/effector/users';

const { addUserFx } = usersStore;

const schema = Yup.object().shape({
  username: Yup.string().required(),
  fullname: Yup.string(),
  email: Yup.string().email(),
  password: Yup.string().required()
})

const styles = {
  error: css`
    margin-bottom: 30px;
  `,
  actionButtons: css`
    display: flex;
    flex-direction: row;
    justify-content: flex-end;
  `,
  cancelButton: css`
    margin-right: 16px;
  `
};


const formProps = [
  'username',
  'password',
  'email',
  'fullname'
]

const requiredFields = [
  'username',
  'password'
]

const submit = async (values, actions) => {
  try {
    await addUserFx(values);
  } catch(e) {
    return;
  }
};

export const UserAddForm = ({
  error,
  onClose
}) => {
  const pending = useStore(addUserFx.pending);

  return (
    <Formik
      initialValues={{
        username: '',
        fullname: '',
        email: '',
        password: ''
      }}
      validationSchema={schema}
      onSubmit={submit}
    >
      {({
        values,
        errors,
        handleChange,
        handleBlur,
        touched,
        handleSubmit
      }) => (<Form>
        <FormContainer>

          {formProps.map(field =>
            <FieldConstructor
              key={field}
              label={field}
              required={requiredFields.includes(field)}
              input={
                <Input
                  value={values[field]}
                  onBlur={handleBlur}
                  onChange={handleChange}
                  name={field}
                  type={field === 'password' ? 'password' : 'text'}
                />
              }
              error={touched[field] && errors[field]}
            />
          )}
          {error || errors.common ? (
            <Alert type="error" className={styles.error}>
              <Text variant="basic">{error || errors.common}</Text>
            </Alert>
          ) : null}
          <div className={styles.actionButtons}>
            {onClose && <Button intent="base" onClick={onClose} className={styles.cancelButton}>Cancel</Button>}
            <Button intent="primary" type='submit' loading={pending}>Add</Button>
          </div>
        </FormContainer>
      </Form>
      )}
    </Formik>

  );
};
