tolk 1.0

const REFUND_BATCH : int = 32

struct Storage {
    id: uint32
    goal: coins
    recieverAddress: address
    creatorAddress: address
    contributions: map<address, coins>
}

fun Storage.load() {
    return Storage.fromCell(contract.getData());
}

fun Storage.save(self) {
    contract.setData(self.toCell());
}

struct (0xCF4D2AC0) Contribution {
    queryId: uint64
}

struct (0x61A586E5) Refund {
    queryId: uint64
}

struct (0xAAAAAAAA) TestReturn {
    queryId: uint64
}

type AllowedMessage = Contribution | Refund | TestReturn

fun addContribution(storage: Storage, address: address, amount: coins) {
    var contribution = storage.contributions.get(address);
    val value = contribution.isFound ? contribution.loadValue() + amount : amount;
    if (contribution.isFound == false) {
        storage.contributions.addIfNotExists(address, value);
    } else {
        storage.contributions.set(address, value);
    }
    Storage.save(storage);
}

fun onInternalMessage(in: InMessage) {
    val msg = lazy AllowedMessage.fromSlice(in.body);
    var storage = lazy Storage.load();

    match (msg) {
        Contribution => {
            val totalCoins = contract.getOriginalBalance();
            if (storage.goal <= totalCoins) {
                val payReciever = createMessage({
                    value: storage.goal,
                    bounce: false,
                    dest: storage.recieverAddress,
                });
                payReciever.send(SEND_MODE_REGULAR);
                val excessCoins = totalCoins - storage.goal;
                if (excessCoins > 0) {
                    val payCreator = createMessage({
                        value: 0,
                        bounce: false,
                        dest: storage.creatorAddress,
                    });
                    payCreator.send(SEND_MODE_CARRY_ALL_BALANCE);
                }
            }
            addContribution(storage, in.senderAddress, in.valueCoins);
            return;
        }
        Refund => {
            var count: int = 0;
            var iterCurrent = storage.contributions.findFirst();

            while (count < REFUND_BATCH && iterCurrent.isFound == true) {
                val contributorAddress = iterCurrent.getKey();
                val contributionAmount = iterCurrent.loadValue();
                val payRefund = createMessage({
                    value: contributionAmount,
                    bounce: false,
                    dest: contributorAddress,
                });
                payRefund.send(SEND_MODE_REGULAR);
                count = count + 1;
                iterCurrent = storage.contributions.iterateNext(iterCurrent);
            }

            Storage.save(storage);
            return;
        }
        TestReturn => {
            val payRefund = createMessage({
                value: 0,
                bounce: false,
                dest: in.senderAddress,
            });
            payRefund.send(SEND_MODE_CARRY_ALL_BALANCE);
        }
        else => {
            return;
        }
    }
}

fun onBouncedMessage(in: InMessageBounced) {}

get fun getId(): uint32 {
    val storage = lazy Storage.load();
    return storage.id;
}

get fun goal(): coins {
    val storage = lazy Storage.load();
    return storage.goal;
}

get fun recieverAddress(): address {
    val storage = lazy Storage.load();
    return storage.recieverAddress;
}

get fun creatorAddress(): address {
    val storage = lazy Storage.load();
    return storage.creatorAddress!;
}
