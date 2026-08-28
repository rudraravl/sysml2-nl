package BirdBiologicalSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQMechanics::*;

    // ---- Value types with units ----
    value type Mass :> Real { unit 'g'; }
    value type Length :> Real { unit 'cm'; }
    value type WingArea :> Real { unit 'cm^2'; }
    value type Force :> Real { unit 'N'; }
    value type Energy :> Real {> Real { unit 'Hz'; }
    value type Volume :> Real { unit 'mL'; }
    value type Velocity :> Real { unit 'm/s'; }
    value type Power :> Real { unit 'W'; }
    value type Pressure :> Real { unit 'kPa'; }
    value type Temperature :> Real { unit 'degC'; }
    value type HeartRate :> Real { unit 'beats/min'; }

    // ---- Item definitions ----
    item def Air;
    item def FreshAir :> Air;
    item def StaleAir :> Air;
    item def Food;
    item def StoredFood :> Food;
    item def GroundFood :> Food;
    item def Nutrients;
    item def Waste;
    item def Blood;
    item def OxygenatedBlood :> Blood;
    item def DeoxygenatedBlood :> Blood;
    item def NeuralSignal;
    item def VisualInformation;
    item def FlightCommand :> NeuralSignal;
    item def ForagingCommand :> NeuralSignal;

    // ---- Port definitions ----
    port def AirInPort { in item FreshAir; }
    port def AirOutPort { out item StaleAir; }
    port def FoodInPort { in item Food; }
    port def FoodOutPort { out item GroundFood; }
    port def NutrientPort { out item Nutrients; }
    port def WastePort { out item Waste; }
    port def DeoxyBloodPort { in item DeoxygenatedBlood; }
    port def OxyBloodPort { out item OxygenatedBlood; }
    port def NeuralInPort { in item NeuralSignal; }
    port def NeuralOutPort { out item NeuralSignal; }
    port def VisualOutPort { out item VisualInformation; }

    // ---- Requirements ----
    requirement def LightweightSkeletonRequirement {
        doc /* The skeleton must be lightweight yet strong to support flight. */
        attribute maxSkeletonMass : Mass = 15.0;
        constraint { skeletonMass <= maxSkeletonMass }
    }

    requirement def FlightMuscleRequirement {
        doc /* Flight muscles must generate sufficient force for wing flapping. */
        attribute minPectoralisForce : Force = 8.0;
        constraint { pectoralisForce >= minPectoralisForce }
    }

    requirement def RespiratoryEfficiencyRequirement {
        doc /* Respiratory system must provide continuous one-way airflow. */
        attribute minAirflowRate : Volume = 50.0;
        constraint { airflowRate >= minAirflowRate }
    }

    requirement def DigestiveThroughputRequirement {
        doc /* Digestive system must rapidly convert food to metabolic energy. */
        attribute minEnergyYield : Energy = 200.0;
        constraint { energyYield >= minEnergyYield }
    }

    requirement def NeuralCoordinationRequirement {
        doc /* Brain must process sensory input and emit precise motor commands. */
        attribute maxReactionTime : Time = 0.05;
        constraint { reactionTime <= maxReactionTime }
    }

    // ---- Attribute definitions ----
    attribute def SkeletonMass :> Mass;
    attribute def PectoralisForce :> Force;
    attribute def AirflowRate :> Volume;
    attribute def EnergyYield :> Energy;
    attribute def ReactionTime :> Time;

    // ---- Part definitions ----

    part def HollowBone {
        attribute mass : Mass;
        attribute length : Length;
        attribute isPneumatic : Boolean = true;
    }

    part def Skeleton {
        attribute skeletonMass : Mass = 12.0;
        part humerus : HollowBone { mass = 1.2; length = 6.0; }
        part furcula : HollowBone { mass = 0.8; length = 4.0; }
        part sternum : HollowBone { mass = 2.0; length = 5.0; }
        part vertebrae : HollowBone[*] { mass = 3.0; length = 0.5; }
        satisfy LightweightSkeletonRequirement {
            attribute skeletonMass : Mass = skeletonMass;
        }
    }

    part def FlightMuscle {
        attribute force : Force;
        attribute contractionFrequency : Frequency;
        port neuralInput : NeuralInPort;
    }

    part def Pectoralis :> FlightMuscle {
        force = 9.5;
        contractionFrequency = 8.0;
        satisfy FlightMuscleRequirement {
            attribute pectoralisForce : Force = force;
        }
    }

    part def Supracoracoideus :> FlightMuscle {
        force = 4.0;
        contractionFrequency = 8.0;
    }

    part def Feather {
        attribute length : Length;
        attribute type : String;
    }

    part def PrimaryFeather :> Feather {
        type = "primary";
        length = 12.0;
    }

    part def SecondaryFeather :> Feather {
        type = "secondary";
        length = 8.0;
    }

    part def CovertFeather :> Feather {
        type = "covert";
        length = 3.0;
    }

    part def Wing {
        attribute wingArea : WingArea = 180.0;
        attribute liftGenerated : Force;
        attribute thrustGenerated : Force;
        port neuralInput : NeuralInPort;
        part primaries : PrimaryFeather[8];
        part secondaries : SecondaryFeather[10];
        part coverts : CovertFeather[20];
    }

    part def Tail {
        attribute stabilizerArea : WingArea = 25.0;
        attribute controlAuthority : Force;
        port neuralInput : NeuralInPort;
        part rectrices : Feather[6] { type = "rectrix"; length = 10.0; }
    }

    part def MusculoskeletalSystem {
        part skeleton : Skeleton;
        part pectoralis : Pectoralis;
        part supracoracoideus : Supracoracoideus;
        part leftWing : Wing;
        part rightWing : Wing;
        part tail : Tail;
        port neuralInput : NeuralInPort;
        port oxyBloodInput : OxyBloodPort;
        port deoxyBloodOutput : DeoxyBloodPort;
        flow from oxyBloodInput to deoxyBloodOutput of DeoxygenatedBlood;
        connection pectoralisNeural from neuralInput to pectoralis.neuralInput;
        connection supracoracoideusNeural from neuralInput to supracoracoideus.neuralInput;
        connection leftWingNeural from neuralInput to leftWing.neuralInput;
        connection rightWingNeural from neuralInput to rightWing.neuralInput;
        connection tailNeural from neuralInput to tail.neuralInput;
    }

    part def Lung {
        attribute gasExchangeArea : WingArea = 60.0;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port deoxyBloodIn : DeoxyBloodPort;
        port oxyBloodOut : OxyBloodPort;
        flow from airIn to airOut of StaleAir;
        flow from deoxyBloodIn to oxyBloodOut of OxygenatedBlood;
    }

    part def AirSac {
        attribute volume : Volume;
        attribute pressure : Pressure;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        flow from airIn to airOut of Air;
    }

    part def RespiratorySystem {
        attribute airflowRate : Volume = 55.0;
        part leftLung : Lung;
        part rightLung : Lung;
        part anteriorAirSacs : AirSac[5] { volume = 8.0; pressure = 1.2; }
        part posteriorAirSacs : AirSac[5] { volume = 10.0; pressure = 1.3; }
        port airIntake : AirInPort;
        port airExhaust : AirOutPort;
        port deoxyBloodIn : DeoxyBloodPort;
        port oxyBloodOut : OxyBloodPort;
        satisfy RespiratoryEfficiencyRequirement {
            attribute airflowRate : Volume = airflowRate;
        }
        connection intakeToLeftLung from airIntake to leftLung.airIn;
        connection intakeToRightLung from airIntake to rightLung.airIn;
        connection leftLungToAnterior from leftLung.airOut to anteriorAirSacs.airIn;
        connection rightLungToAnterior from rightLung.airOut to anteriorAirSacs.airIn;
        connection posteriorToLeftLung from posteriorAirSacs.airOut to leftLung.airIn;
        connection posteriorToRightLung from posteriorAirSacs.airOut to rightLung.airIn;
        connection anteriorToExhaust from anteriorAirSacs.airOut to airExhaust;
        connection deoxyToLeftLung from deoxyBloodIn to leftLung.deoxyBloodIn;
        connection deoxyToRightLung from deoxyBloodIn to rightLung.deoxyBloodIn;
        connection leftLungOxy from leftLung.oxyBloodOut to oxyBloodOut;
        connection rightLungOxy from rightLung.oxyBloodOut to oxyBloodOut;
    }

    part def Beak {
        attribute graspingForce : Force = 2.0;
        port foodIn : FoodInPort;
        port foodOut : FoodOutPort;
        flow from foodIn to foodOut of Food;
    }

    part def Crop {
        attribute storageCapacity : Volume = 15.0;
        port foodIn : FoodInPort;
        port foodOut : FoodOutPort;
        flow from foodIn to foodOut of StoredFood;
    }

    part def Gizzard {
        attribute grindingForce : Force = 5.0;
        port foodIn : FoodInPort;
        port foodOut : FoodOutPort;
        flow from foodIn to foodOut of GroundFood;
    }

    part def Intestines {
        attribute absorptionEfficiency : Real = 0.85;
        attribute energyYield : Energy = 250.0;
        port foodIn : FoodInPort;
        port nutrientOut : NutrientPort;
        port wasteOut : WastePort;
        flow from foodIn to nutrientOut of Nutrients;
        flow from foodIn to wasteOut of Waste;
        satisfy DigestiveThroughputRequirement {
            attribute energyYield : Energy = energyYield;
        }
    }

    part def DigestiveSystem {
        part beak : Beak;
        part crop : Crop;
        part gizzard : Gizzard;
        part intestines : Intestines;
        port foodIntake : FoodInPort;
        port nutrientOut : NutrientPort;
        port wasteOut : WastePort;
        connection beakToCrop from beak.foodOut to crop.foodIn;
        connection cropToGizzard from crop.foodOut to gizzard.foodIn;
        connection gizzardToIntestines from gizzard.foodOut to intestines.foodIn;
        connection intakeToBeak from foodIntake to beak.foodIn;
        connection nutrientsOut from intestines.nutrientOut to nutrientOut;
        connection wasteOut from intestines.wasteOut to wasteOut;
    }

    part def Eye {
        attribute focalLength : Length = 1.2;
        attribute visualAcuity : Real = 0.95;
        port visualOut : VisualOutPort;
    }

    part def Brain {
        attribute reactionTime : Time = 0.03;
        attribute processingPower : Power = 0.5;
        port visualIn : VisualOutPort;
        port neuralOut : NeuralOutPort;
        satisfy NeuralCoordinationRequirement {
            attribute reactionTime : Time = reactionTime;
        }
        action def processSensoryInput {
            in visual : VisualInformation;
            out command : NeuralSignal;
        }
        action def coordinateFlight {
            in visual : VisualInformation;
            out command : FlightCommand;
        }
        action def coordinateForaging {
            in visual : VisualInformation;
            out command : ForagingCommand;
        }
        perform processSensoryInput;
        perform coordinateFlight;
        perform coordinateForaging;
    }

    // ---- Top-level Bird ----
    part def Bird {
        attribute bodyMass : Mass = 85.0;
        attribute bodyTemperature : Temperature = 40.0;
        attribute heartRate : HeartRate = 400.0;

        part musculoskeletalSystem : MusculoskeletalSystem;
        part respiratorySystem : RespiratorySystem;
        part digestiveSystem : DigestiveSystem;
        part brain : Brain;
        part leftEye : Eye;
        part rightEye : Eye;

        // External ports
        port airIntake : AirInPort;
        port airExhaust : AirOutPort;
        port foodIntake : FoodInPort;
        port wasteOut : WastePort;

        // Internal connections
        connection airIntakeToRespiratory from airIntake to respiratorySystem.airIntake;
        connection airExhaustFromRespiratory from respiratorySystem.airExhaust to airExhaust;
        connection foodIntakeToDigestive from foodIntake to digestiveSystem.foodIntake;
        connection wasteFromDigestive from digestiveSystem.wasteOut to wasteOut;
        connection leftEyeToBrain from leftEye.visualOut to brain.visualIn;
        connection rightEyeToBrain from rightEye.visualOut to brain.visualIn;
        connection brainToMusculoskeletal from brain.neuralOut to musculoskeletalSystem.neuralInput;
        connection oxyBloodToMusculoskeletal from respiratorySystem.oxyBloodOut to musculoskeletalSystem.oxyBloodInput;
        connection deoxyBloodFromMusculoskeletal from musculoskeletalSystem.deoxyBloodOutput to respiratorySystem.deoxyBloodIn;
        connection nutrientsToBody from digestiveSystem.nutrientOut to respiratorySystem.deoxyBloodIn;

        // State machine
        state def BirdLifecycle {
            entry action { /* initialize organism */ }
            state resting {
                entry action { heartRate = 250.0; }
                do action { conserveEnergy(); }
            }
            state active {
                entry action { heartRate = 500.0; }
                state flying {
                    entry action { send FlightCommand to musculoskeletalSystem.neuralInput; }
                    do action { flapWings(); }
                }
                state foraging {
                    entry action { send ForagingCommand to musculoskeletalSystem.neuralInput; }
                    do action { locateAndConsumeFood(); }
                }
                transition resting_to_active
                    from resting to active
                    when bodyEnergy < threshold;
                transition active_to_resting
                    from active to resting
                    when bodyEnergy >= highThreshold;
                transition flying_to_foraging
                    from flying to foraging
                    when hungerLevel > hungerThreshold;
                transition foraging_to_flying
                    from foraging to flying
                    when cropFull == true;
            }
        }

        attribute bodyEnergy : Energy = 300.0;
        attribute threshold : Energy = 150.0;
        attribute highThreshold : Energy = 280.0;
        attribute hungerLevel : Real = 0.0;
        attribute hungerThreshold : Real = 0.7;
        attribute cropFull : Boolean = false;

        action def conserveEnergy {
            /* reduce metabolic rate */
        }
        action def flapWings {
            /* drive pectoralis and supracoracoideus contractions */
        }
        action def locateAndConsumeFood {
            /* use visual input to find and ingest food */
        }

        exhibit BirdLifecycle;
    }
}
