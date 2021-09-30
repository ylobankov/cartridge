describe('Screenshots', () => {
	before(() => {
		cy.task('tarantool', {
			code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = 'test-cluster-cookie',
        replicasets = {{
          alias = 'test-replicaset',
          roles = {},
          servers = {{http_port = 8080}},
        }}
      })

      _G.cluster:start()
      return true
    `,
		}).should('deep.eq', [true]);
	});

	after(() => {
		cy.task('tarantool', { code: `cleanup()` });
	});

	const pages = ['cluster/dashboard', 'cluster/users', 'cluster/configuration', 'cluster/code'];
	const indicator = ['.meta-test__ProbeServerBtn', '.meta-test__addUserBtn', '.meta-test__DownloadBtn',
		'.meta-test__Code__apply_idle'];
	const sizes = ['macbook-16'];

	const prepareTest = page => {
		const now = new Date(Date.UTC(2019, 1, 1)).getTime();
		cy.clock(now);
		cy.visit('/admin/'+page);
		cy.viewport(1920, 1080);
	};

	sizes.forEach(size => {
		let i =0;
		pages.forEach(page => {
			it(`Should match previous screenshot '${page} Page' When '${size}' resolution`, () => {
				prepareTest(page);
				cy.get(indicator[i]);
				i++;
				cy.matchImageSnapshot();
			});
		});
	});



});