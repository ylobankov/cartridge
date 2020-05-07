// @flow
import React from 'react';
import { connect } from 'react-redux';
import { Button, PageLayout, PageSection } from '@tarantool.io/ui-kit';
import { UserAddModal } from 'src/components/UserAddModal';
import { UserEditModal } from 'src/components/UserEditModal';
import { UserRemoveModal } from 'src/components/UserRemoveModal';
import { UsersTable } from '../../components/UsersTable';
import AuthToggleButton from 'src/components/AuthToggleButton';
import usersStore from 'src/store/effector/users';

const { showUserAddModal } = usersStore;
const { AppTitle } = window.tarantool_enterprise_core.components;

type UsersProps = {
  implements_add_user: boolean,
  implements_list_users: boolean,
  implements_remove_user: boolean,
  implements_edit_user: boolean,
  showToggleAuth: boolean
};

const Users = (
  {
    implements_add_user,
    implements_list_users,
    implements_remove_user,
    implements_edit_user,
    showToggleAuth
  }: UsersProps
) => {
  return (
    <PageLayout>
      <AppTitle title='Users' />
      <PageSection
        title='Users list'
        topRightControls={[
          showToggleAuth && <AuthToggleButton />,
          implements_add_user && (
            <Button
              className='meta-test__addUserBtn'
              text='Add user'
              intent='primary'
              onClick={showUserAddModal}
            >
              Add user
            </Button>
          )
        ]}
      >
        {implements_list_users && (
          <UsersTable
            implements_remove_user={implements_remove_user}
            implements_edit_user={implements_edit_user}
          />
        )}
      </PageSection>
      <UserRemoveModal />
      {implements_add_user && <UserAddModal />}
      <UserEditModal />
    </PageLayout>
  );
};

const mapStateToProps = ({
  app: {
    authParams: {
      implements_add_user,
      implements_check_password,
      implements_list_users,
      implements_remove_user,
      implements_edit_user
    }
  }
}) => ({
  implements_add_user,
  showToggleAuth: implements_check_password && (implements_add_user || implements_list_users),
  implements_list_users,
  implements_remove_user,
  implements_edit_user
});

export default connect(mapStateToProps)(Users);
