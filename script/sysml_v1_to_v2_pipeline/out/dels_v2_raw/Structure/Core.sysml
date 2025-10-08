package Structure::Core;
import Libraries::Units;

part def ActiveResource;
ActiveResource {
  part resource: ActiveResource;
  part resource: ActiveResource;
  part relationshipBetween: ActiveResourceRelationship;
  part canExecute: Process;
  part produces: Product;
  part outputResources: PassiveResource;
  part inputResources: PassiveResource;
  part memberActiveResource: ActiveResource;
  part sourceResource: ActiveResource;
  part targetResource: ActiveResource;
}

part def Scheduler;
Scheduler {
  part queue: Queue;
  part resourceAcquirer: ResourceAcquirer;
}

part def Equipment;
Equipment {
  part controller: RealtimeController;
}

part def AssembledProduct;
AssembledProduct {
}

part def Material;
Material {
  part requiredBy: Product;
}

part def AdmissionGate;
AdmissionGate {
  part canExecute: Admit;
  part incomingTask: inDELSTask;
  part availableTask: outDELSTask;
  part rejectedTask: outDELSTask;
}

part def Task;
Task {
  part targetProduct: Product;
  part authorizesExecuting: Process;
  part subTask: Task;
  part currentDELS: DELS;
}

part def Router;
Router {
  part canExecute: Route;
  part inTask: inDELSTask;
  part outTask: outDELSTask;
  part readWriteProcessPlan: ReadWriteProcessPlan;
  part resourceAcquirer: ResourceAcquirer;
}

part def MaterialHandlingChannel;
MaterialHandlingChannel {
}

part def ConsumableResource;
ConsumableResource {
}

part def BatchCapacityResource;
BatchCapacityResource {
}

part def DELS;
DELS {
  part availableTaskStore: Queue;
  part acquireResources: ResourceAcquirer;
  part functionalCapability: Process;
  part completedTaskStore: Queue;
  part releaseResources: Release;
  part routing: Router;
  part controller: OperationalController;
  part inResource: inDELSResource;
  part setUp: ChangeState;
  part incomingTasks: inDELSTask;
  part completedTasks: Task;
  part outgoingTasks: outDELSTask;
  part availableTasks: Task;
  part outResource: outDELSResource;
  part location: Location;
  part serviceProvider: DELS;
  part serviceRequestor: DELS;
  part childDELS: DELS;
  part relationshipBetween: Contract;
  part inprocessTasks: Task;
  part parentDELS: DELS;
  part mhc: MaterialHandlingChannel;
}

part def ReusableResource;
ReusableResource {
}

part def SendTaskToResource;
SendTaskToResource {
}

part def Release;
Release {
  part releasedResource: outDELSResource;
  part completedTask: outDELSTask;
  part resource: inDELSResource;
}

part def Endpoint Node;
Endpoint Node {
  part point: VectorOfReals;
  part endpointOfSegment: Rectangular Path Segment;
  part L_Intersection: Lshaped Intersection;
  part T_intersection: Tshaped Intersection;
  part +_intersection: +shaped Intersection;
}

part def Process-Oriented Layout;
Process-Oriented Layout {
}

part def Rectangular Path Intersection;
Rectangular Path Intersection {
  part intersectingObject: Rectangular Path;
}

part def StructuredCapacityPool;
StructuredCapacityPool {
  part aggregateResourcePool: AggregateResource;
  part batchResourcePool: BatchCapacityResource;
}

part def Facility;
Facility {
  part containedResources: Resource;
  part hasActualLayout: Layout;
  part location: Location;
}

part def Internal Node;
Internal Node {
  part point: VectorOfReals;
}

part def Placement;
Placement {
  part object: Layout Object;
  part space: Physical Space;
  part offset: VectorOfReals;
  part orientation: SquareMatrixOfReals;
  part parentLayout: Layout;
}

part def CapacitatedResource;
CapacitatedResource {
}

part def Information;
Information {
}

part def DiscreteStateResource;
DiscreteStateResource {
  part currentService: Process;
}

part def Lshaped Intersection;
Lshaped Intersection {
  part endpoint: Endpoint Node;
}

part def HeterogeneousAggregateResource;
HeterogeneousAggregateResource {
}

part def Two Rectangular Path Intersection;
Two Rectangular Path Intersection {
}

part def MobileResource;
MobileResource {
  part CurrentLocation: Location;
}

part def Tshaped Intersection;
Tshaped Intersection {
  part endpoint: Endpoint Node;
}

part def PassiveResource;
PassiveResource {
}

part def Layout Object;
Layout Object {
  part 2Dgeometry: 2Dgeometry;
  part 3Dgeometry: 3Dgeometry;
}

part def AggregatedProduct;
AggregatedProduct {
}

part def ResourceAcquirer;
ResourceAcquirer {
  part canExecute: ResourceAcquire;
  part inTask: inDELSTask;
  part acquiredResource: outDELSResource;
  part availableResource: inDELSResource;
  part outTask: outDELSTask;
}

part def Personnel;
Personnel {
}

part def Product;
Product {
  part billOfMaterial: Material;
  part components: Product;
  part authorizedBy: Task;
  part requiredInputResources: Resource;
  part createdBy: Process;
}

part def RealtimeController;
RealtimeController {
}

part def Resource;
Resource {
  part isLocatedIn: Facility;
  part memberResource: Resource;
  part resourceGroup: Resource;
  part requiredByProduct: Product;
  part requiredByProcess: Process;
}

part def Layout Object With Access;
Layout Object With Access {
  part accessAt: Interface Point;
}

part def Physical Space;
Physical Space {
  part geometry: 2Dgeometry;
  part hasLayout: Layout;
  part parentFacility: Facility;
}

part def Rectangular Path;
Rectangular Path {
  part ownedSegment: Rectangular Path Segment;
  part sharedSegment: Rectangular Path Intersection;
}

part def Layout Object For Movement;
Layout Object For Movement {
  part incidentTo: Interface Point;
}

part def PerishableResource;
PerishableResource {
}

part def +shaped Intersection;
+shaped Intersection {
  part endpoint: Endpoint Node;
}

part def Layout;
Layout {
  part layoutForSpace: Physical Space;
  part actualLayoutOfSpace: Facility;
  part placements: Placement;
}

part def HeterogeneousAggregatedProduct;
HeterogeneousAggregatedProduct {
}

part def ResourceToTask;
ResourceToTask {
}

part def SimpleCapacityPool;
SimpleCapacityPool {
  part resourcePool: UnitCapacityResource;
}

part def MaterialHandlingChannel;
MaterialHandlingChannel {
  part source: ActiveResource;
  part target: ActiveResource;
}

part def Rectangular Path Segment;
Rectangular Path Segment {
  part internalNode: Internal Node;
  part owningPath: Rectangular Path;
  part endpoint: Endpoint Node;
  part incidentTo: Interface Point;
}

part def Contract;
Contract {
  part serviceProvider: DELS;
  part serviceRequestor: DELS;
  part requiredService: Process;
}

part def HomogenousAggregateResource;
HomogenousAggregateResource {
}

part def Queue;
Queue {
  part canExecute: Sequence;
  part outTask: outDELSTask;
  part inTask: inDELSTask;
}

part def Product-Oriented Layout;
Product-Oriented Layout {
}

part def UnitCapacityResource;
UnitCapacityResource {
}

part def ReadWriteProcessPlan;
ReadWriteProcessPlan {
  part inTask: inDELSTask;
  part canExecute: UpdateProcessPlan;
  part outTask: outDELSTask;
}

part def Interface Point;
Interface Point {
  part point: VectorOfReals;
}

part def StationaryResource;
StationaryResource {
  part CurrentLocation: Location;
}

part def Actuator;
Actuator {
}

part def ActiveResourceRelationship;
ActiveResourceRelationship {
}

part def AtomicResource;
AtomicResource {
  part resourcePool: Resource;
  part memberResource: Resource;
}

part def AggregateResource;
AggregateResource {
  part resourcePool: Resource;
}

part def ChangeState;
ChangeState {
  part targetResource: inDELSResource;
  part auxillaryResources: inDELSResource;
  part releasedResources: outDELSResource;
  part canExecute: ChangeState;
  part overheadTask: outDELSTask;
}

part def HomogeneousAggregatedProduct;
HomogeneousAggregatedProduct {
}
