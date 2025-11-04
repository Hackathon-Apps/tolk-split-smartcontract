import { toNano } from '@ton/core';
import { AccomuletedWallet } from '../wrappers/AccomuletedWallet';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const accomuletedWallet = provider.open(
        AccomuletedWallet.createFromConfig(
            {
                id: Math.floor(Math.random() * 10000),
                counter: 0,
            },
            await compile('AccomuletedWallet')
        )
    );

    await accomuletedWallet.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(accomuletedWallet.address);

    console.log('ID', await accomuletedWallet.getID());
}
