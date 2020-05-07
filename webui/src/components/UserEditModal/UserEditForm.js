import React, { useEffect } from 'react';
import { useStore } from 'effector-react';
import { css } from 'emotion';
import { Alert, Button, Input, Text } from '@tarantool.io/ui-kit';
import { FieldConstructor, FormContainer } from '../FieldGroup';
import { Formik, Form } from 'formik';
import * as Yup from 'yup';
import * as R from 'ramda';
import usersStore from 'src/store/effector/users';

const { $userToMutate, editUserFx } = usersStore;

const schema = Yup.object().shape({
  fullname: Yup.string(),
  email: Yup.string().email(),
  password: Yup.string()
})


const styles = {
  error: css`
    min-height: 24px;
    margin: 0 0 24px;
    color: #f5222d;
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


const submit = async (values, actions) => {
  const obj = R.pickAll(['email', 'fullname', 'username'], values)
  if (values.password) {
    obj.password = values.password
  }
  try {
    await editUserFx(obj);
  } catch(e) {
    return;
  }
};


export const UserEditForm = ({
  error,
  onClose
}) => {
  const { username, fullname, email } = useStore($userToMutate);
  const pending = useStore(editUserFx.pending);

  return (
    <Formik
      initialValues={{
        fullname: fullname || '',
        email: email || '',
        password: ''
      }}
      validationSchema={schema}
      onSubmit={(values, actions) => submit({ ...values, username }, actions)}
    >
      {({
        values,
        errors,
        touched,
        handleChange,
        handleBlur,
        handleSubmit
      }) => (
        <Form>
          <FormContainer>
            <FieldConstructor
              key='password'
              label='New password'
              input={
                <Input
                  value={values['password']}
                  onBlur={handleBlur}
                  onChange={handleChange}
                  name='password'
                  type='password'
                />
              }
              error={touched['password'] && errors['password']}
            />
            <FieldConstructor
              key='email'
              label='email'
              input={
                <Input
                  value={values['email']}
                  onBlur={handleBlur}
                  onChange={handleChange}
                  name='email'
                  type='email'
                />
              }
              error={touched['email'] && errors['email']}
            />
            <FieldConstructor
              key='fullname'
              label='fullname'
              input={
                <Input
                  value={values['fullname']}
                  onBlur={handleBlur}
                  onChange={handleChange}
                  name='fullname'
                />
              }
              error={touched['fullname'] && errors['fullname']}
            />
            {error || errors.common ? (
              <Alert type="error" className={styles.error}>
                <Text variant="basic">{error || errors.common}</Text>
              </Alert>
            ) : null}
            <div className={styles.actionButtons}>
              {onClose && <Button intent="base" onClick={onClose} className={styles.cancelButton}>Cancel</Button>}
              <Button intent="primary" type='submit' loading={pending}>Save</Button>
            </div>
          </FormContainer>
        </Form>
      )}
    </Formik>
  );
};
