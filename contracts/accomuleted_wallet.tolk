tolk 1.0

struct Storage {
    id: uint32
    goal: coins
    recieverAddress: address
    creatorAddress: address
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

type AllowedMessage = Contribution | Refund

fun onInternalMessage(in: InMessage) {
    val msg = lazy AllowedMessage.fromSlice(in.body);
    var storage = lazy Storage.load();

    match (msg) {
        Contribution => {
            val totalCoins = contract.getOriginalBalance() + in.valueCoins;
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
            return;
        }
        Refund => {
            val payCreator = createMessage({
                value: 0,
                bounce: false,
                dest: storage.creatorAddress,
            });
            payCreator.send(SEND_MODE_CARRY_ALL_BALANCE);
        }
        else => {
            assert (in.body.isEmpty()) throw 0xFFFF;
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
