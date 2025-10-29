// Model a vending machine that is able to dispose items.
```sysml
package VendingMachineModel {

  // Define the type of item that the vending machine handles
  part Item {
    // Example properties for an item could be added here:
    // attribute name : String;
    // attribute weight : QuantityValue;
  }

  // Define the VendingMachine itself
  part VendingMachine {
    // The vending machine has a behavior to dispose of items.
    // This behavior takes an 'Item' as an input, representing the item to be disposed.
    behavior disposeItem {
      input itemToDispose : Item;
      // The internal steps or effects of disposing an item would be defined within this behavior.
      // For this model, defining the capability is sufficient.
    }

    // Other typical vending machine behaviors could be added:
    // behavior vendItem {
    //   input selection : Item;
    //   input payment : Money;
    //   output dispensedItem : Item;
    //   output change : Money;
    // }
  }

}
```
