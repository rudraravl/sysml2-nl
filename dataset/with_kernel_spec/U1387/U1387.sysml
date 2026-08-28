package BirdBiologicalSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    // ===== Value Types =====
    value type BirdMass :> Mass;
    value type BodyLength :> Length;
    value type WingArea :> Area;
    value type MuscleForce :> Force;
    value type WingbeatFrequency :> Frequency;
    value type MetabolicEnergy :> Energy;
    value type AirVolume :> Volume;
    value type LiftToDragRatio :> Real;

    // ===== Items =====
    item def NeuralSignal;
    item def Air;
    item def OxygenatedBlood;
    item def DeoxygenatedBlood;
    item def Food;
    item def VisualInformation;
    item def Nutrient;
    item def MechanicalForce;

    // ===== Port Definitions =====
    port def NeuralCommandPort {
        in command : NeuralSignal;
    }

    port def VisualDataPort {
        in visualData : VisualInformation;
    }

    port def BloodOutputPort {
        out oxyBlood : OxygenatedBlood;
    }

    port def DeoxygenatedBloodPort {
        out deoxyBlood : DeoxygenatedBlood;
    }

    port def AirFlowPort {
        in inflow : Air;
        out outflow : Air;
    }

    port def FoodIntakePort {
        in foodItem : Food;
    }

    port def NutrientOutputPort {
        out nutrients : Nutrient;
    }

    port def ForceOutputPort {
        out force : MechanicalForce;
    }

    // ===== Feather Definitions =====
    part def Feather {
        attribute length : BodyLength;
    }

    part def PrimaryFeather :> Feather {
        doc /* Primaries provide thrust for propulsion. */
    }

    part def SecondaryFeather :> Feather {
        doc /* Secondaries provide lift. */
    }

    part def CovertFeather :> Feather {
        doc /* Coverts smooth the aerodynamic profile. */
    }

    // ===== Skeleton =====
    part def Bone {
        attribute isHollow : Boolean = true;
        attribute length : BodyLength;
    }

    part def Skeleton {
        part keel : Bone;
        part skull : Bone;
        part ribs : Bone[12];
        part vertebrae : Bone[20];
        attribute totalMass : BirdMass;
    }

    // ===== Flight Muscles =====
    part def FlightMuscle {
        attribute maxForce : MuscleForce;
        port neuralIn : NeuralCommandPort;
        port bloodSupply : BloodOutputPort~;
        port deoxygenatedOut : DeoxygenatedBloodPort;
        port energyIn : NutrientOutputPort~;
        port forceOut : ForceOutputPort;
    }

    part def Pectoralis :> FlightMuscle {
        doc /* Primary downstroke muscle driving the wing beat. */
    }

    part def Supracoracoideus :> FlightMuscle {
        doc /* Primary upstroke muscle for wing recovery. */
    }

    part def MusculoskeletalSystem {
        part skeleton : Skeleton;
        part pectoralis : Pectoralis;
        part supracoracoideus : Supracoracoideus;
        port neuralIn : NeuralCommandPort;
        port oxygenIn : BloodOutputPort~;
        port deoxygenatedOut : DeoxygenatedBloodPort;
        port energyIn : NutrientOutputPort~;
        port forceOut : ForceOutputPort;

        connect neuralIn to pectoralis.neuralIn;
        connect neuralIn to supracoracoideus.neuralIn;
        connect pectoralis.forceOut to forceOut;
        connect supracoracoideus.forceOut to forceOut;
        connect oxygenIn to pectoralis.bloodSupply;
        connect oxygenIn to supracoracoideus.bloodSupply;
        connect pectoralis.deoxygenatedOut to deoxygenatedOut;
        connect supracoracoideus.deoxygenatedOut to deoxygenatedOut;
        connect energyIn to pectoralis.energyIn;
        connect energyIn to supracoracoideus.energyIn;
    }

    // ===== Wing =====
    part def Wing {
        attribute span : BodyLength;
        attribute area : WingArea;
        part primaries : PrimaryFeather[10];
        part secondaries : SecondaryFeather[15];
        part coverts : CovertFeather[20];
        port forceIn : ForceOutputPort~;
        port liftOut : ForceOutputPort;
        port thrustOut : ForceOutputPort;
    }

    // ===== Tail =====
    part def Tail {
        doc /* Stabilizer and rudder for control and maneuverability during flight. */
        attribute length : BodyLength;
        part feathers : CovertFeather[12];
        port controlIn : NeuralCommandPort;
        port stabilizationOut : ForceOutputPort;
    }

    // ===== Respiratory System =====
    part def Lung {
        port airSupply : AirFlowPort;
        port deoxygenatedBloodIn : DeoxygenatedBloodPort~;
        port oxygenatedBloodOut : BloodOutputPort;
    }

    part def AirSac {
        attribute volume : AirVolume;
        port airConnection : AirFlowPort;
    }

    part def RespiratorySystem {
        part leftLung : Lung;
        part rightLung : Lung;
        part anteriorAirSac1 : AirSac;
        part anteriorAirSac2 : AirSac;
        part posteriorAirSac1 : AirSac;
        part posteriorAirSac2 : AirSac;
        port externalAir : AirFlowPort;
        port deoxygenatedBloodIn : DeoxygenatedBloodPort~;
        port bloodOutput : BloodOutputPort;

        connect externalAir to posteriorAirSac1.airConnection;
        connect externalAir to posteriorAirSac2.airConnection;
        connect posteriorAirSac1.airConnection to leftLung.airSupply;
        connect posteriorAirSac2.airConnection to rightLung.airSupply;
        connect leftLung.airSupply to anteriorAirSac1.airConnection;
        connect rightLung.airSupply to anteriorAirSac2.airConnection;
        connect anteriorAirSac1.airConnection to externalAir;
        connect anteriorAirSac2.airConnection to externalAir;
        connect deoxygenatedBloodIn to leftLung.deoxygenatedBloodIn;
        connect deoxygenatedBloodIn to rightLung.deoxygenatedBloodIn;
        connect leftLung.oxygenatedBloodOut to bloodOutput;
        connect rightLung.oxygenatedBloodOut to bloodOutput;
    }

    // ===== Digestive System =====
    part def Beak {
        doc /* Grasping and initial food intake. */
        port foodIn : FoodIntakePort;
        port foodOut : FoodIntakePort~;
    }

    part def Crop {
        doc /* Temporary food storage. */
        port foodIn : FoodIntakePort;
        port foodOut : FoodIntakePort~;
    }

    part def Gizzard {
        doc /* Mechanical grinding of food. */
        port foodIn : FoodIntakePort;
        port foodOut : FoodIntakePort~;
    }

    part def Intestines {
        doc /* Nutrient absorption. */
        port foodIn : FoodIntakePort;
        port nutrientOutput : NutrientOutputPort;
    }

    part def DigestiveSystem {
        part beak : Beak;
        part crop : Crop;
        part gizzard : Gizzard;
        part intestines : Intestines;
        port foodIntake : FoodIntakePort;
        port nutrientOutput : NutrientOutputPort;

        connect foodIntake to beak.foodIn;
        connect beak.foodOut to crop.foodIn;
        connect crop.foodOut to gizzard.foodIn;
        connect gizzard.foodOut to intestines.foodIn;
        connect intestines.nutrientOutput to nutrientOutput;
    }

    // ===== Eye =====
    part def Eye {
        port visualOut : VisualDataPort~;
    }

    // ===== Brain =====
    part def Brain {
        attribute processingState : String;
        port leftVisualIn : VisualDataPort;
        port rightVisualIn : VisualDataPort;
        port leftPectoralisCommand : NeuralCommandPort~;
        port rightPectoralisCommand : NeuralCommandPort~;
        port leftSupracoracoideusCommand : NeuralCommandPort~;
        port rightSupracoracoideusCommand : NeuralCommandPort~;
        port tailControlCommand : NeuralCommandPort~;
    }

    // ===== Actions =====
    action def LowerMetabolicRate {
        doc /* Reduce metabolic rate to conserve energy during rest. */
    }

    action def RaiseMetabolicRate {
        doc /* Increase metabolic rate upon waking. */
    }

    action def InitiateWingbeats {
        doc /* Begin rhythmic contraction of pectoralis and supracoracoideus. */
    }

    action def MaintainAerodynamicForces {
        doc /* Sustain lift and thrust through wing and tail adjustments. */
    }

    action def ScanForFood {
        doc /* Use visual system to locate food sources. */
    }

    action def ConsumeFood {
        doc /* Intake and process food through the digestive system. */
    }

    // ===== State Machine =====
    state def BirdStates {
        state resting {
            doc /* Conserve energy; reduced metabolic and muscular activity. */
            entry action LowerMetabolicRate;
            exit action RaiseMetabolicRate;
        }

        state active {
            state flying {
                doc /* Powered flight for travel or migration. */
                entry action InitiateWingbeats;
                do action MaintainAerodynamicForces;
            }

            state foraging {
                doc /* Locate and consume food to replenish energy. */
                entry action ScanForFood;
                do action ConsumeFood;
            }

            transition from flying to foraging;
            transition from Foraging to flying;
        }

        transition from resting to active;
        transition from active to resting;
    }

    // ===== Requirements =====
    requirement def LightweightStructureRequirement {
        doc /* The skeleton must be lightweight yet strong, featuring hollow bones. */
    }

    requirement def AerodynamicEfficiencyRequirement {
        doc /* Wings and tail must provide sufficient lift, thrust, and control for powered flight. */
    }

    requirement def EnergyMetabolismRequirement {
        doc /* Digestive system must efficiently convert food into metabolic energy for sustained flight. */
    }

    requirement def RespiratoryEfficiencyRequirement {
        doc /* Respiratory system must provide continuous one-way air flow for high oxygen delivery. */
    }

    requirement def NeuralCoordinationRequirement {
        doc /* Brain shall process visual information and coordinate muscle contractions for wing movement. */
    }

    // ===== Bird Definition =====
    part def Bird {
        attribute bodyMass : BirdMass;
        attribute bodyLength : BodyLength;

        part musculoskeletalSystem : MusculoskeletalSystem;
        part leftWing : Wing;
        part rightWing : Wing;
        part tail : Tail;
        part respiratorySystem : RespiratorySystem;
        part digestiveSystem : DigestiveSystem;
        part brain : Brain;
        part leftEye : Eye;
        part rightEye : Eye;

        port airIntake : AirFlowPort;
        port foodIntake : FoodIntakePort;
        port liftOut : ForceOutputPort;
        port thrustOut : ForceOutputPort;

        connect leftEye.visualOut to brain.leftVisualIn;
        connect rightEye.visualOut to brain.rightVisualIn;

        connect brain.leftPectoralisCommand to musculoskeletalSystem.pectoralis.neuralIn;
        connect brain.rightPectoralisCommand to musculoskeletalSystem.pectoralis.neuralIn;
        connect brain.leftSupracoracoideusCommand to musculoskeletalSystem.supracoracoideus.neuralIn;
        connect brain.rightSupracoracoideusCommand to musculoskeletalSystem.supracoracoideus.neuralIn;
        connect brain.tailControlCommand to tail.controlIn;

        connect musculoskeletalSystem.forceOut to leftWing.forceIn;
        connect musculoskeletalSystem.forceOut to rightWing.forceIn;

        connect respiratorySystem.bloodOutput to musculoskeletalSystem.oxygenIn;
        connect musculoskeletalSystem.deoxygenatedOut to respiratorySystem.deoxygenatedBloodIn;

        connect digestiveSystem.nutrientOutput to musculoskeletalSystem.energyIn;

        connect airIntake to respiratorySystem.externalAir;
        connect foodIntake to digestiveSystem.foodIntake;
        connect leftWing.liftOut to liftOut;
        connect rightWing.liftOut to liftOut;
        connect leftWing.thrustOut to thrustOut;
        connect rightWing.thrustOut to thrustOut;
    }

    // ===== Bird Instance =====
    part birdInstance : Bird {
        exhibit BirdStates;
        satisfy LightweightStructureRequirement by musculoskeletalSystem.skeleton;
        satisfy AerodynamicEfficiencyRequirement by leftWing, rightWing, tail;
        satisfy EnergyMetabolismRequirement by digestiveSystem;
        satisfy RespiratoryEfficiencyRequirement by respiratorySystem;
        satisfy NeuralCoordinationRequirement by brain, leftEye, rightEye;
    }
}
