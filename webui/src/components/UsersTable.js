// @flow
import React, { useEffect } from 'react';
import { useStore } from 'effector-react';
import { css, cx } from 'emotion';
import * as R from 'ramda';
import {
  Button,
  Dropdown,
  DropdownItem,
  IconBoxNoData,
  IconMore,
  IconSpinner,
  TiledList,
  NonIdealState
} from '@tarantool.io/ui-kit';
import usersStore from 'src/store/effector/users';

const {
  showUserEditModal,
  showUserRemoveModal,
  resetUsersList,
  fetchUsersListFx,
  $usersList
} = usersStore;

const styles = {
  clickableRow: css`
    cursor: pointer;
  `,
  row: css`
    display: flex;
    flex-direction: row;
    flex-wrap: nowrap;
  `,
  username: css`
    font-size: 16px;
    font-weight: 600;
  `,
  field: css`
    width: 300px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex-grow: 0;
    flex-shrink: 0;
    font-size: 14px;
    font-family: Open Sans;
    line-height: 22px;
    color: #000000;
  `,
  actions: css`
    margin-left: auto;
  `
};

type UsersTableColumn = {
  title: string,
  dataIndex: string,
  className?: string
};

const columns: UsersTableColumn[] = [
  {
    title: 'Username',
    dataIndex: 'username',
    className: styles.username
  },
  {
    title: 'Full name',
    dataIndex: 'fullname',
    key: 'fullname'
  },
  {
    title: 'E-mail',
    dataIndex: 'email'
  }
];

const buttons = {
  edit: {
    text: 'Edit user',
    handler: ({ item }) => showUserEditModal(item.username)
  },
  remove: {
    text: 'Remove user',
    handler: ({ item }) => showUserRemoveModal(item.username),
    className: css`color: rgba(245, 34, 45, 0.65);`
  }
}

type UsersTableProps = {
  implements_edit_user: boolean,
  implements_remove_user: boolean
}

export const UsersTable = (
  {
    implements_edit_user,
    implements_remove_user
  }: UsersTableProps
) => {
  useEffect(
    () => {
      fetchUsersListFx();
      return resetUsersList;
    },
    []
  );

  const items = useStore($usersList);

  const fetching = useStore(fetchUsersListFx.pending);

  const actionButtons = (edit, remove) => (item, className) => {
    const filtered = R.compose(
      R.map(({ handler, text, className }) => (
        <DropdownItem
          className={className}
          onClick={() => handler({ item })}
        >
          {text}
        </DropdownItem>
      )),
      R.filter(R.identity),
      R.map(([key, exists]) => exists ? buttons[key] : null),
      R.toPairs
    )({ edit, remove })
    return filtered.length > 0
      ? (
        <Dropdown className={className} items={filtered}>
          <Button icon={IconMore} intent='iconic' size='s' />
        </Dropdown>
      )
      : null
  }

  const actionButton = actionButtons(implements_edit_user, implements_remove_user)

  if (fetching)
    return (
      <NonIdealState icon={IconSpinner} title='Loading...' />
    );

  return items.length ? (
    <TiledList
      className='meta-test__UsersTable'
      itemRender={item =>
        <div
          className={styles.row}
        >
          {columns.map(({ dataIndex, className }) =>
            <div className={cx(styles.field, className)} title={item[dataIndex]}>{item[dataIndex]}</div>
          )}
          {
            actionButton(item, styles.actions)
          }
        </div>}
      items={items}
      columns={columns}
      dataSource={items}
      itemKey='username'
      outer={false}
    />
  ) : (
    <NonIdealState icon={IconBoxNoData} title='No data' />
  );
};
