import React from 'react';
import { css } from 'emotion';
import { useStore } from 'effector-react';
import { Alert, ConfirmModal, Text } from '@tarantool.io/ui-kit';
import styled from 'react-emotion';
import usersStore from 'src/store/effector/users';

const { $userRemoveModal, hideModal, removeUserFx } = usersStore;

const Container = styled.div`
  padding: 0 16px;
  font-size: 14px;
  font-family: Open Sans;
  line-height: 22px;
`

const styles = {
  error: css`
    min-height: 24px;
    margin: 16px 0 24px;
  `
};

export const UserRemoveModal = () => {
  const { error, username, visible } = useStore($userRemoveModal);
  const pending = useStore(removeUserFx.pending);

  return (
    <ConfirmModal
      className='meta-test__UserRemoveModal'
      title="Please confirm"
      visible={visible}
      onCancel={hideModal}
      onConfirm={() => removeUserFx(username)}
      confirmText="Remove"
      confirmPreloader={pending}
    >
      <Container>
        Removing user {username}
        {error ? (
          <Alert type="error" className={styles.error}>
            <Text variant="basic">{error}</Text>
          </Alert>
        ) : null}
      </Container>
    </ConfirmModal>
  );
};
