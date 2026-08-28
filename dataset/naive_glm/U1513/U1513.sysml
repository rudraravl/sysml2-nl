package TaccolaHydraulicSystem {
    import ISQ::*;
    import ScalarValues::*;
    
    // ===== Value Types with Units =====
    
    value type VolumeValue :> Real {
        unit : VolumeUnit;
    }
    attribute volumeUnit : VolumeUnit = L;
    
    value type LengthValue :> Real {
        unit : LengthUnit;
    }
    attribute lengthUnit : LengthUnit = m;
    
    value type FlowRateValue :> Real {
        unit : FlowRateUnit;
    }
    attribute flowRateUnit : FlowRateUnit = L/s;
    
    value type RotationalSpeedValue :> Real {
        unit : RotationalSpeedUnit;
    }
    attribute rotationalSpeedUnit : RotationalSpeedUnit = rpm;
    
    value type TorqueValue :> Real {
        unit : TorqueUnit;
    }
    attribute torqueUnit : TorqueUnit = N*m;
    
    value type ForceValue :> Real {
        unit : ForceUnit;
    }
    attribute forceUnit : ForceUnit = N;
    
    value type PressureValue :> Real {
        unit : PressureUnit;
    }
    attribute pressureUnit : PressureUnit = Pa;
    
    value type LinearDisplacementValue :> Real {
        unit : LengthUnit;
    }
    
    value type MassValue :> Real {
        unit : MassUnit;
    }
    attribute massUnit : MassUnit = kg;
    
    value type FrequencyValue :> Real {
        unit : FrequencyUnit;
    }
    attribute frequencyUnit : FrequencyUnit = Hz;
    
    value type TimeValue :> Real {
        unit : TimeUnit;
    }
    attribute timeUnit : TimeUnit = s;
    
    value type AngleValue :> Real {
        unit : AngleUnit;
    }
    attribute angleUnit : AngleUnit = rad;
    
    // ===== Item Types =====
    
    item def Water {
        attribute density : MassValue = 1000 [kg/m^3];
        attribute temperature : Real = 20;
    }
    
    item def MechanicalRotation {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute direction : String = "clockwise";
    }
    
    item def LinearMotion {
        attribute displacement : LinearDisplacementValue;
        attribute velocity : LinearDisplacementValue;
        attribute force : ForceValue;
        attribute direction : String = "reciprocating";
    }
    
    item def AirFlow {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    // ===== Port Definitions =====
    
    port def WaterPort {
        out item water : Water;
        attribute flowRate : FlowRateValue;
    }
    
    port def RotationPort {
        out item rotation : MechanicalRotation;
    }
    
    port def LinearMotionPort {
        out item motion : LinearMotion;
    }
    
    port def AirPort {
        out item air : AirFlow;
    }
    
    // ===== Requirements =====
    
    requirement def ReservoirRequirement {
        doc /* The upper reservoir must collect water and trigger the siphon at a predetermined level. */
        attribute triggerLevel : LengthValue = 1.5 [m];
        attribute reservoirCapacity : VolumeValue = 500 [L];
        attribute fillTime : TimeValue = 120 [s];
        
        requirement triggerSiphonAtLevel {
            subject reservoirLevel : LengthValue;
            require reservoirLevel >= triggerLevel;
        }
    }
    
    requirement def SiphonRequirement {
        doc /* The siphon must automatically activate when the reservoir reaches trigger level and rapidly release water. */
        attribute dischargeRate : FlowRateValue = 50 [L/s];
        attribute activationTime : TimeValue = 2 [s];
        attribute dischargeDuration : TimeValue = 10 [s];
        
        requirement autoActivation {
            subject siphonState : String;
            require siphonState == "active" :>> triggerSiphonAtLevel.reservoirLevel;
        }
    }
    
    requirement def WaterWheelRequirement {
        doc /* The undershot water wheel must rotate when struck by siphon discharge water. */
        attribute nominalSpeed : RotationalSpeedValue = 12 [rpm];
        attribute bucketCount : Integer = 16;
        attribute wheelDiameter : LengthValue = 3.0 [m];
        attribute minTorque : TorqueValue = 500 [N*m];
        
        requirement rotateOnFlow {
            subject inputFlow : FlowRateValue;
            require inputFlow >= 20 [L/s] implies wheelSpeed >= nominalSpeed;
        }
    }
    
    requirement def CrankRequirement {
        doc /* The crank must convert continuous rotation into reciprocating linear motion. */
        attribute strokeLength : LinearDisplacementValue = 0.5 [m];
        attribute crankRadius : LengthValue = 0.25 [m];
        
        requirement convertMotion {
            subject inputRotation : RotationalSpeedValue;
            require inputRotation > 0 [rpm] implies outputMotion.direction == "reciprocating";
        }
    }
    
    requirement def BellowsRequirement {
        doc /* The pumping bellows must draw water from a lower source and lift it to an elevated destination. */
        attribute liftHeight : LengthValue = 5.0 [m];
        attribute pumpRate : FlowRateValue = 5 [L/s];
        attribute cyclesPerMinute : FrequencyValue = 12 [Hz];
        
        requirement pumpWater {
            subject bellowsActive : String;
            require bellowsActive == "operating" implies pumpedFlow >= pumpRate;
        }
    }
    
    requirement def SystemAutomationRequirement {
        doc /* The system must operate continuously without external power or manual intervention. */
        attribute externalPowerRequired : Boolean = false;
        attribute manualInterventionRequired : Boolean = false;
        
        requirement selfRegulating {
            require externalPowerRequired == false and manualInterventionRequired == false;
        }
    }
    
    // ===== Part Definitions =====
    
    part def UpperReservoir {
        doc /* Collects water from a source. Triggers siphon when water reaches predetermined level. */
        attribute capacity : VolumeValue = 500 [L];
        attribute triggerLevel : LengthValue = 1.5 [m];
        attribute currentLevel : LengthValue;
        attribute currentVolume : VolumeValue;
        
        port inflow : WaterPort;
        port outflow : WaterPort;
        
        requirement reservoirReq : ReservoirRequirement;
        
        action def FillAction {
            in waterIn : Water;
            out volume : VolumeValue;
            out level : LengthValue;
        }
        
        action fill : FillAction {
            in waterIn = inflow.water;
        }
        
        exhibit state def ReservoirStates {
            idle;
            filling {
                entry action { currentVolume' = currentVolume + inflow.flowRate * 0.001; }
            }
            full {
                entry action { outflow.flowRate' = 0; }
            }
            overflowing {
                entry action { outflow.flowRate' = 50; }
            }
            empty {
                entry action { currentVolume' = 0; }
            }
            
            transition idle_to_filling first if inflow.flowRate > 0 then filling;
            transition filling_to_full then full if currentLevel >= triggerLevel;
            transition full_to_overflowing then overflowing;
            transition overflowing_to_empty then empty if currentVolume <= 0;
            transition empty_to_filling then filling if inflow.flowRate > 0;
        }
        
        exhibit state behavior : ReservoirStates;
    }
    
    part def AutomaticSiphon {
        doc /* Automatically triggers when reservoir reaches trigger level. Rapidly releases accumulated water volume. */
        attribute dischargeRate : FlowRateValue = 50 [L/s];
        attribute activationLevel : LengthValue = 1.5 [m];
        attribute isActive : Boolean = false;
        attribute dischargeDuration : TimeValue = 10 [s];
        
        port inflow : WaterPort;
        port outflow : WaterPort;
        
        requirement siphonReq : SiphonRequirement;
        
        action def DischargeAction {
            in waterIn : Water;
            out waterOut : Water;
            out flowRate : FlowRateValue;
        }
        
        action discharge : DischargeAction {
            in waterIn = inflow.water;
            out waterOut = outflow.water;
            out flowRate = outflow.flowRate;
        }
        
        exhibit state def SiphonStates {
            inactive;
            priming {
                entry action { isActive' = true; }
            }
            active {
                entry action { outflow.flowRate' = dischargeRate; }
            }
            drained {
                entry action { outflow.flowRate' = 0; isActive' = false; }
            }
            
            transition inactive_to_priming first then priming if inflow.flowRate > 0;
            transition priming_to_active then active;
            transition active_to_drained then drained if inflow.flowRate == 0;
            transition drained_to_inactive then inactive;
        }
        
        exhibit state behavior : SiphonStates;
    }
    
    part def UndershotWaterWheel {
        doc /* Large undershot water wheel with buckets. Rotates when struck by siphon discharge water. */
        attribute diameter : LengthValue = 3.0 [m];
        attribute bucketCount : Integer = 16;
        attribute nominalSpeed : RotationalSpeedValue = 12 [rpm];
        attribute currentSpeed : RotationalSpeedValue;
        attribute outputTorque : TorqueValue = 500 [N*m];
        attribute isRotating : Boolean = false;
        
        port waterInflow : WaterPort;
        port rotationOutput : RotationPort;
        
        requirement wheelReq : WaterWheelRequirement;
        
        action def RotateAction {
            in waterIn : Water;
            in flowRate : FlowRateValue;
            out rotation : MechanicalRotation;
        }
        
        action rotate : RotateAction {
            in waterIn = waterInflow.water;
            in flowRate = waterInflow.flowRate;
            out rotation = rotationOutput.rotation;
        }
        
        exhibit state def WheelStates {
            stationary;
            accelerating {
                entry action { currentSpeed' = currentSpeed + 1; isRotating' = true; }
            }
            rotating {
                entry action { currentSpeed' = nominalSpeed; }
            }
            decelerating {
                entry action { currentSpeed' = currentSpeed - 1; }
            }
            
            transition stationary_to_accelerating first then accelerating if waterInflow.flowRate > 0;
            transition accelerating_to_rotating then rotating if currentSpeed >= nominalSpeed;
            transition rotating_to_decelerating then decelerating if waterInflow.flowRate == 0;
            transition decelerating_to_stationary then stationary if currentSpeed <= 0;
        }
        
        exhibit state behavior : WheelStates;
    }
    
    part def OakAxleShaft {
        doc /* Sturdy oak axle shaft that transfers rotational energy from wheel to crank. */
        attribute material : String = "oak";
        attribute length : LengthValue = 2.0 [m];
        attribute diameter : LengthValue = 0.15 [m];
        attribute maxTorque : TorqueValue = 2000 [N*m];
        attribute efficiency : Real = 0.95;
        
        port rotationInput : RotationPort;
        port rotationOutput : RotationPort;
        
        action def TransferRotationAction {
            in rotationIn : MechanicalRotation;
            out rotationOut : MechanicalRotation;
        }
        
        action transfer : TransferRotationAction {
            in rotationIn = rotationInput.rotation;
            out rotationOut = rotationOutput.rotation;
        }
    }
    
    part def CrankMechanism {
        doc /* Converts the wheel's continuous rotation into reciprocating back-and-forth linear motion. */
        attribute crankRadius : LengthValue = 0.25 [m];
        attribute strokeLength : LinearDisplacementValue = 0.5 [m];
        attribute currentDisplacement : LinearDisplacementValue;
        attribute outputForce : ForceValue = 800 [N];
        attribute isMoving : Boolean = false;
        
        port rotationInput : RotationPort;
        port linearOutput : LinearMotionPort;
        
        requirement crankReq : CrankRequirement;
        
        action def ConvertMotionAction {
            in rotation : MechanicalRotation;
            out motion : LinearMotion;
        }
        
        action convert : ConvertMotionAction {
            in rotation = rotationInput.rotation;
            out motion = linearOutput.motion;
        }
        
        exhibit state def CrankStates {
            idle;
            converting {
                entry action { isMoving' = true; currentDisplacement' = crankRadius; }
            }
            
            transition idle_to_converting first then converting if rotationInput.rotation.speed > 0;
            transition converting_to_idle then idle if rotationInput.rotation.speed == 0;
        }
        
        exhibit state behavior : CrankStates;
    }
    
    part def PumpingBellows {
        doc /* Acts as the system's pump. Draws water from a lower source and lifts it to an elevated destination. */
        attribute liftHeight : LengthValue = 5.0 [m];
        attribute pumpRate : FlowRateValue = 5 [L/s];
        attribute chamberVolume : VolumeValue = 10 [L];
        attribute cyclesPerMinute : FrequencyValue = 12 [Hz];
        attribute isOperating : Boolean = false;
        attribute currentPumpFlow : FlowRateValue;
        
        port motionInput : LinearMotionPort;
        port waterIntake : WaterPort;
        port waterDischarge : WaterPort;
        
        requirement bellowsReq : BellowsRequirement;
        
        action def PumpAction {
            in motion : LinearMotion;
            in waterIn : Water;
            out waterOut : Water;
            out flowRate : FlowRateValue;
        }
        
        action pump : PumpAction {
            in motion = motionInput.motion;
            in waterIn = waterIntake.water;
            out waterOut = waterDischarge.water;
            out flowRate = waterDischarge.flowRate;
        }
        
        exhibit state def BellowsStates {
            idle;
            expanding {
                entry action { isOperating' = true; }
            }
            contracting {
                entry action { currentPumpFlow' = pumpRate; }
            }
            paused {
                entry action { currentPumpFlow' = 0; }
            }
            
            transition idle_to_expanding first then expanding if motionInput.motion.displacement > 0;
            transition expanding_to_contracting then contracting;
            transition contracting_to_expanding then expanding if motionInput.motion.displacement > 0;
            transition contracting_to_paused then paused if motionInput.motion.displacement == 0;
            transition paused_to_idle then idle;
        }
        
        exhibit state behavior : BellowsStates;
    }
    
    part def LowerWaterSource {
        doc /* Lower water source from which the bellows draws water. */
        attribute availableVolume : VolumeValue = 10000 [L];
        attribute sourceLevel : LengthValue = 0 [m];
        
        port waterOutput : WaterPort;
        
        action def SupplyWaterAction {
            out water : Water;
            out flowRate : FlowRateValue;
        }
        
        action supply : SupplyWaterAction {
            out water = waterOutput.water;
            out flowRate = waterOutput.flowRate;
        }
    }
    
    part def ElevatedDestination {
        doc /* Elevated destination to which water is lifted by the bellows. */
        attribute elevation : LengthValue = 5.0 [m];
        attribute receivedVolume : VolumeValue = 0 [L];
        
        port waterInput : WaterPort;
        
        action def ReceiveWaterAction {
            in water : Water;
            in flowRate : FlowRateValue;
        }
        
        action receive : ReceiveWaterAction {
            in water = waterInput.water;
            in flowRate = waterInput.flowRate;
        }
    }
    
    part def WaterSupplySource {
        doc /* Natural water source feeding the upper reservoir via gravity. */
        attribute flowRate : FlowRateValue = 5 [L/s];
        attribute available : Boolean = true;
        
        port waterOutput : WaterPort;
        
        action def SupplyAction {
            out water : Water;
            out rate : FlowRateValue;
        }
        
        action supply : SupplyAction {
            out water = waterOutput.water;
            out rate = waterOutput.flowRate;
        }
    }
    
    // ===== Top-Level System =====
    
    part def TaccolaHydraulicEngine {
        doc /* Automated, self-regulating hydraulic machine that pumps water using only gravity and water flow. */
        
        requirement systemAutomationReq : SystemAutomationRequirement;
        
        part waterSupply : WaterSupplySource;
        part upperReservoir : UpperReservoir;
        part siphon : AutomaticSiphon;
        part waterWheel : UndershotWaterWheel;
        part axleShaft : OakAxleShaft;
        part crank : CrankMechanism;
        part bellows : PumpingBellows;
        part lowerSource : LowerWaterSource;
        part elevatedDest : ElevatedDestination;
        
        // Connections
        connection : WaterPort connect waterSupply.waterOutput to upperReservoir.inflow;
        connection : WaterPort connect upperReservoir.outflow to siphon.inflow;
        connection : WaterPort connect siphon.outflow to waterWheel.waterInflow;
        connection : RotationPort connect waterWheel.rotationOutput to axleShaft.rotationInput;
        connection : RotationPort connect axleShaft.rotationOutput to crank.rotationInput;
        connection : LinearMotionPort connect crank.linearOutput to bellows.motionInput;
        connection : WaterPort connect lowerSource.waterOutput to bellows.waterIntake;
        connection : WaterPort connect bellows.waterDischarge to elevatedDest.waterInput;
        
        // System-level state machine
        exhibit state def SystemOperationalStates {
            doc /* The system transitions through operational states in a continuous automated cycle. */
            
            idle {
                doc /* System remains idle until a water supply is available. */
                entry action { /* waiting for water supply */ }
            }
            filling {
                doc /* Reservoir collects water from the source. */
                entry action { upperReservoir.fill(); }
            }
            overflowing_and_operating {
                doc /* Siphon triggered, wheel turns, pumping occurs. */
                entry action { 
                    siphon.discharge(); 
                    waterWheel.rotate(); 
                    axleShaft.transfer(); 
                    crank.convert(); 
                    bellows.pump(); 
                }
            }
            draining {
                doc /* Reservoir empties through the siphon; flow stops. */
                entry action { /* siphon draining, wheel decelerating */ }
            }
            
            transition idle_to_filling first then filling if waterSupply.available == true;
            transition filling_to_overflowing then overflowing_and_operating if upperReservoir.currentLevel >= upperReservoir.triggerLevel;
            transition overflowing_to_draining then draining if siphon.isActive == false;
            transition draining_to_filling then filling if upperReservoir.currentVolume <= 0 and waterSupply.available == true;
            transition draining_to_idle then idle if waterSupply.available == false;
        }
        
        exhibit state behavior : SystemOperationalStates;
        
        // System-level actions
        action def OperateCycleAction {
            doc /* Complete operational cycle of the Taccola hydraulic engine. */
            in supplyWater : Water;
            out pumpedWater : Water;
            out liftedTo : LengthValue;
        }
        
        action operateCycle : OperateCycleAction {
            in supplyWater = waterSupply.waterOutput.water;
            out pumpedWater = elevatedDest.waterInput.water;
            out liftedTo = elevatedDest.elevation;
        }
    }
    
    // ===== Verification =====
    
    verification def VerifyAutomation {
        subject system : TaccolaHydraulicEngine;
        objective {
            doc /* Verify the system operates without external power or manual intervention. */
            require system.systemAutomationReq.externalPowerRequired == false;
            require system.systemAutomationReq.manualInterventionRequired == false;
        }
    }
    
    verification def VerifyContinuousCycle {
        subject system : TaccolaHydraulicEngine;
        objective {
            doc /* Verify the system transitions through all operational states in a cycle. */
            require system.state behavior.idle_to_filling.occurred == true;
            require system.state behavior.filling_to_overflowing.occurred == true;
            require system.state behavior.overflowing_to_draining.occurred == true;
            require system.state behavior.draining_to_filling.occurred == true;
        }
    }
    
    verification def VerifyPumpingFunction {
        subject system : TaccolaHydraulicEngine;
        objective {
            doc /* Verify water is lifted from lower source to elevated destination. */
            require system.elevatedDest.receivedVolume > 0 [L];
            require system.elevatedDest.elevation >= 5.0 [m];
        }
    }
}
