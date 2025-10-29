// Model a vending machine that is able to dispose items.
package VendingMachineModel {
    item def Item;
    action def DisposeItem {
        in itemToDispose : Item;
    }
    part def VendingMachine {
        perform DisposeItem;
    }
}
