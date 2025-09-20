// package: automotive.example
define part Car {
  part engine: Engine;
  part wheels: Wheel[4];
}

define part Engine {
  attr power: Real;        // kW
  attr fuelType: String;   // "gasoline" | "diesel" | "electric"
}

define part Wheel {
  attr radius: Real;       // cm
}

define behavior StartEngine for Car {
  // pre: fuelType != "electric" implies fuelLevel > 0
  // post: engineRunning == true within 2s
}
