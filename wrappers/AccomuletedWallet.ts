import { Null } from '@tact-lang/compiler';
import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';
import { Coins } from '@ton/sandbox/dist/config/config.tlb-gen';

export type AccomuletedWalletConfig = {
    id: number;
    recieverAddress: Address;
    creatorAddress: Address;
    goal: Coins
    feeCollectorAddress: Address;
    contributions: null;
};

export function accomuletedWalletConfigToCell(config: AccomuletedWalletConfig): Cell {
    return beginCell()
        .storeUint(config.id, 32)
        .storeCoins(config.goal.grams)
        .storeAddress(config.recieverAddress)
        .storeAddress(config.creatorAddress)
        .storeAddress(config.feeCollectorAddress)
        .endCell();
}

export const Opcodes = {
    OP_INCREASE: 0x7e8764ef,
    OP_RESET: 0x3a752f06,
};

export class AccomuletedWallet implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) { }

    static createFromAddress(address: Address) {
        return new AccomuletedWallet(address);
    }

    static createFromConfig(config: AccomuletedWalletConfig, code: Cell, workchain = 0) {
        const data = accomuletedWalletConfigToCell(config);
        const init = { code, data };
        return new AccomuletedWallet(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }

    async sendIncrease(
        provider: ContractProvider,
        via: Sender,
        opts: {
            increaseBy: number;
            value: bigint;
            queryID?: number;
        }
    ) {
        await provider.internal(via, {
            value: opts.value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                .storeUint(Opcodes.OP_INCREASE, 32)
                .storeUint(opts.queryID ?? 0, 64)
                .storeUint(opts.increaseBy, 32)
                .endCell(),
        });
    }

    async sendReset(
        provider: ContractProvider,
        via: Sender,
        opts: {
            value: bigint;
            queryID?: number;
        }
    ) {
        await provider.internal(via, {
            value: opts.value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                .storeUint(Opcodes.OP_RESET, 32)
                .storeUint(opts.queryID ?? 0, 64)
                .endCell(),
        });
    }

    async getCounter(provider: ContractProvider) {
        const result = await provider.get('currentCounter', []);
        return result.stack.readNumber();
    }

    async getID(provider: ContractProvider) {
        const result = await provider.get('getId', []);
        return result.stack.readNumber();
    }
}
