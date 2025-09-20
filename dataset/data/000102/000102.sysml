// package: warehouse.robotics
define part Warehouse {
  part robot: Robot[2];
  part shelf: Shelf[10];
}

define part Robot {
  attr id: String;
  attr battery: Real;      // 0..100
}

define part Shelf {
  attr levelCount: Integer; // shelves per rack
}

define behavior PickAndPlace for Robot {
  // pre: battery >= 20
  // post: itemMoved == true within 5s
}
