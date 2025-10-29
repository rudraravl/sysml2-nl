// Create a power unit that supplies electricity to servers and prevents overload.
```sysml
// Define a quantity for electrical power
quantity def ElectricalPower {
  base Units::watt; // Assuming Units library is available
}

// Define an interface for supplying electrical power
interface def ElectricalPowerSupply {
  flow power: ElectricalPower;
}

// Define the PowerUnit part
part def PowerUnit {
  // Output port for supplying electricity
  output electricityOut: ElectricalPowerSupply;

  // Property to define the maximum power this unit can supply
  property maxOutputPower: ElectricalPower;

  // Function to prevent overload
  // This function would typically monitor the 'power' flow on 'electricityOut'
  // and ensure it does not exceed 'maxOutputPower'.
  function preventOverload {
    // Input representing the current power being supplied
    input currentPower: ElectricalPower;
    // Output indicating if an overload condition is detected
    output overloadDetected: Boolean;
    // The behavior of this function would involve comparing currentPower
    // with maxOutputPower and taking appropriate action (e.g., signaling overload,
    // reducing power, or shutting down) if currentPower exceeds maxOutputPower.
  }
}

// Define a Server part that consumes electrical power
part def Server {
  // Input port for receiving electricity
  input electricityIn: ElectricalPowerSupply;
}

// Example of a system using the PowerUnit and Server
part def System {
  part powerUnit: PowerUnit;
  part server: Server;

  // Connect the power unit's output to the server's input
  connect powerUnit.electricityOut to server.electricityIn;
}
```
