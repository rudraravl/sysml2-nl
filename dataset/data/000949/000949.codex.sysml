package TrompeBasedCompressedAirSystem {
    import ScalarValues::*;
    import Quantities::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure;
    attribute def FlowRate :> ISQ::volumeFlowRate;
    attribute def MassFlowRate :> ISQ::massFlowRate;
    attribute def Length :> ISQ::length;
    attribute def Area :> ISQ::area;
    attribute def Velocity :> ISQ::speed;
    attribute def Efficiency :> ScalarValues::Real;
    attribute def Fraction :> ScalarValues::Real;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Power :> ISQ::power;
    attribute def Time :> ISQ::duration;

    item def Water {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
    }

    item def Air {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        attribute humidityRatio : Fraction;
    }

    item def AirWaterMixture {
        attribute waterFlowRate : FlowRate;
        attribute airFlowRate : FlowRate;
        attribute voidFraction : Fraction;
        attribute pressure : Pressure;
        attribute velocity : Velocity;
    }

    item def SeparatedWater {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute residualAirFraction : Fraction;
    }

    item def CompressedAir {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        attribute moistureFraction : Fraction;
    }

    port def WaterInletPort {
        in item water : Water;
    }

    port def AirInletPort {
        in item air : Air;
    }

    port def MixturePort {
        inout item mixture : AirWaterMixture;
    }

    port def WaterOutletPort {
        out item water : SeparatedWater;
    }

    port def CompressedAirPort {
        out item air : CompressedAir;
    }

    port def ControlPort {
        in attribute enable : Boolean;
        in attribute targetAirPressure : Pressure;
        out attribute operatingMode : String;
    }

    part def IntakeWeir {
        attribute upstreamHead : Length = 12.0 [m];
        attribute trashRackOpenArea : Area = 1.8 [m^2];
        attribute designWaterFlow : FlowRate = 0.42 [m^3/s];

        port waterSupply : WaterInletPort;
        port waterToPenstock : WaterOutletPort;

        action regulateWaterSupply {
            in item incomingWater : Water;
            out item conditionedWater : SeparatedWater;
            constraint {
                conditionedWater.flowRate <= designWaterFlow;
                conditionedWater.pressure == incomingWater.pressure;
            }
        }
    }

    part def Penstock {
        attribute length : Length = 38.0 [m];
        attribute internalDiameter : Length = 0.55 [m];
        attribute hydraulicLossCoefficient : Real = 0.08;
        attribute designVelocity : Velocity = 1.77 [m/s];

        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;

        action conveyFallingWater {
            in item inletWater : Water;
            out item acceleratedWater : SeparatedWater;
            constraint {
                acceleratedWater.flowRate == inletWater.flowRate;
                acceleratedWater.pressure < inletWater.pressure;
            }
        }
    }

    part def AirAdmissionHead {
        attribute intakeArea : Area = 0.032 [m^2];
        attribute checkValveCrackingPressure : Pressure = 200.0 [Pa];
        attribute entrainmentCoefficient : Real = 0.18;

        port atmosphericAir : AirInletPort;
        port fallingWater : WaterInletPort;
        port mixtureOut : MixturePort;

        action entrainAir {
            in item water : Water;
            in item air : Air;
            out item mixture : AirWaterMixture;
            constraint {
                mixture.waterFlowRate == water.flowRate;
                mixture.airFlowRate == water.flowRate * entrainmentCoefficient;
                mixture.pressure <= air.pressure;
                mixture.voidFraction > 0.0;
                mixture.voidFraction < 0.5;
            }
        }
    }

    part def DowncomerPipe {
        attribute depth : Length = 31.0 [m];
        attribute internalDiameter : Length = 0.42 [m];
        attribute hydrostaticCompressionPressure : Pressure = 304000.0 [Pa];
        attribute allowableSurgePressure : Pressure = 450000.0 [Pa];

        port mixtureIn : MixturePort;
        port mixtureOut : MixturePort;

        action compressEntrainedAir {
            in item inletMixture : AirWaterMixture;
            out item compressedMixture : AirWaterMixture;
            constraint {
                compressedMixture.waterFlowRate == inletMixture.waterFlowRate;
                compressedMixture.airFlowRate <= inletMixture.airFlowRate;
                compressedMixture.pressure > inletMixture.pressure;
                compressedMixture.pressure <= allowableSurgePressure;
            }
        }
    }

    part def SeparationChamber {
        attribute chamberVolume : ISQ::volume = 18.0 [m^3];
        attribute normalWaterLevel : Length = 2.7 [m];
        attribute minimumGasSpaceVolume : ISQ::volume = 4.5 [m^3];
        attribute separationEfficiency : Efficiency = 0.96;

        port mixtureIn : MixturePort;
        port compressedAirOut : CompressedAirPort;
        port waterOut : WaterOutletPort;

        action separateAirAndWater {
            in item mixture : AirWaterMixture;
            out item air : CompressedAir;
            out item water : SeparatedWater;
            constraint {
                air.pressure == mixture.pressure;
                water.pressure == mixture.pressure;
                air.flowRate == mixture.airFlowRate * separationEfficiency;
                water.flowRate == mixture.waterFlowRate;
                water.residualAirFraction == 1.0 - separationEfficiency;
            }
        }
    }

    part def Tailrace {
        attribute dischargeElevation : Length = 0.0 [m];
        attribute outletDiameter : Length = 0.62 [m];
        attribute maximumBackPressure : Pressure = 8000.0 [Pa];

        port waterIn : WaterInletPort;
        port dischargedWater : WaterOutletPort;

        action returnWaterToStream {
            in item separatedWater : Water;
            out item returnedWater : SeparatedWater;
            constraint {
                returnedWater.flowRate == separatedWater.flowRate;
                returnedWater.pressure <= maximumBackPressure;
            }
        }
    }

    part def AirReceiver {
        attribute receiverVolume : ISQ::volume = 11.0 [m^3];
        attribute maximumAllowablePressure : Pressure = 410000.0 [Pa];
        attribute minimumServicePressure : Pressure = 240000.0 [Pa];
        attribute storedAirPressure : Pressure;
        attribute storedAirTemperature : Temperature;

        port airIn : CompressedAirPort;
        port airOut : CompressedAirPort;

        action bufferCompressedAir {
            in item incomingAir : CompressedAir;
            out item serviceAir : CompressedAir;
            constraint {
                incomingAir.pressure <= maximumAllowablePressure;
                serviceAir.pressure >= minimumServicePressure;
                serviceAir.pressure <= incomingAir.pressure;
            }
        }
    }

    part def MoistureSeparator {
        attribute removalEfficiency : Efficiency = 0.92;
        attribute drainInterval : Time = 600.0 [s];

        port wetAirIn : CompressedAirPort;
        port dryAirOut : CompressedAirPort;

        action removeCondensate {
            in item wetAir : CompressedAir;
            out item conditionedAir : CompressedAir;
            constraint {
                conditionedAir.pressure < wetAir.pressure;
                conditionedAir.flowRate == wetAir.flowRate;
                conditionedAir.moistureFraction == wetAir.moistureFraction * (1.0 - removalEfficiency);
            }
        }
    }

    part def ServiceManifold {
        attribute nominalPressure : Pressure = 275000.0 [Pa];
        attribute maximumDemandFlow : FlowRate = 0.068 [m^3/s];

        port airSupply : CompressedAirPort;
        port processAir : CompressedAirPort;
        port instrumentationAir : CompressedAirPort;

        action distributeAir {
            in item supplyAir : CompressedAir;
            out item processAirFlow : CompressedAir;
            out item instrumentationAirFlow : CompressedAir;
            constraint {
                processAirFlow.pressure == nominalPressure;
                instrumentationAirFlow.pressure == nominalPressure;
                processAirFlow.flowRate + instrumentationAirFlow.flowRate <= maximumDemandFlow;
            }
        }
    }

    part def ControlAndProtection {
        attribute lowWaterFlowTrip : FlowRate = 0.12 [m^3/s];
        attribute highPressureTrip : Pressure = 390000.0 [Pa];
        attribute lowReceiverPressureAlarm : Pressure = 230000.0 [Pa];
        attribute commandedTargetPressure : Pressure = 275000.0 [Pa];

        port control : ControlPort;

        state def TrompeOperatingState {
            state Off;
            state Priming;
            state Compressing;
            state Standby;
            state Fault;

            transition first Off;
            transition Off_to_Priming
                first Off
                then Priming
                accept enable
                if enable == true;

            transition Priming_to_Compressing
                first Priming
                then Compressing
                if measuredWaterFlow >= lowWaterFlowTrip;

            transition Compressing_to_Standby
                first Compressing
                then Standby
                if measuredReceiverPressure >= commandedTargetPressure;

            transition Standby_to_Compressing
                first Standby
                then Compressing
                if measuredReceiverPressure < commandedTargetPressure;

            transition Any_to_Fault
                first Compressing
                then Fault
                if measuredReceiverPressure > highPressureTrip;

            transition Fault_to_Off
                first Fault
                then Off
                accept reset;
        }

        attribute measuredWaterFlow : FlowRate;
        attribute measuredReceiverPressure : Pressure;
    }

    part def TrompeCompressedAirPlant {
        attribute grossHead : Length = 31.0 [m];
        attribute designWaterFlow : FlowRate = 0.42 [m^3/s];
        attribute designAirDeliveryPressure : Pressure = 275000.0 [Pa];
        attribute designAirFlow : FlowRate = 0.058 [m^3/s];
        attribute overallCompressionEfficiency : Efficiency = 0.54;
        attribute hydraulicInputPower : Power = 127700.0 [W];
        attribute primaryFunction : String = "Convert the potential energy of falling water into a continuous supply of compressed air without a mechanical compressor.";

        port streamWaterIn : WaterInletPort;
        port ambientAirIn : AirInletPort;
        port serviceAirOut : CompressedAirPort;
        port waterReturnOut : WaterOutletPort;
        port operatorControl : ControlPort;

        part intake : IntakeWeir;
        part penstock : Penstock;
        part airHead : AirAdmissionHead;
        part downcomer : DowncomerPipe;
        part separator : SeparationChamber;
        part tailrace : Tailrace;
        part receiver : AirReceiver;
        part dryer : MoistureSeparator;
        part manifold : ServiceManifold;
        part controller : ControlAndProtection;

        connect streamWaterIn to intake.waterSupply;
        connect intake.waterToPenstock to penstock.waterIn;
        connect penstock.waterOut to airHead.fallingWater;
        connect ambientAirIn to airHead.atmosphericAir;
        connect airHead.mixtureOut to downcomer.mixtureIn;
        connect downcomer.mixtureOut to separator.mixtureIn;
        connect separator.waterOut to tailrace.waterIn;
        connect tailrace.dischargedWater to waterReturnOut;
        connect separator.compressedAirOut to receiver.airIn;
        connect receiver.airOut to dryer.wetAirIn;
        connect dryer.dryAirOut to manifold.airSupply;
        connect manifold.processAir to serviceAirOut;
        connect operatorControl to controller.control;

        action produceCompressedAir {
            in item sourceWater : Water;
            in item atmosphericAir : Air;
            out item deliveredAir : CompressedAir;
            out item dischargedWater : SeparatedWater;

            first startWaterAdmission;
            then entrainAtmosphericAir;
            then hydrostaticallyCompressMixture;
            then separateCompressedAir;
            then bufferAndDryAir;
            then distributeServiceAir;

            action startWaterAdmission {
                in item sourceWater : Water;
                out item fallingWater : Water;
            }

            action entrainAtmosphericAir {
                in item fallingWater : Water;
                in item atmosphericAir : Air;
                out item airWaterMixture : AirWaterMixture;
            }

            action hydrostaticallyCompressMixture {
                in item airWaterMixture : AirWaterMixture;
                out item compressedMixture : AirWaterMixture;
            }

            action separateCompressedAir {
                in item compressedMixture : AirWaterMixture;
                out item compressedAir : CompressedAir;
                out item separatedWater : SeparatedWater;
            }

            action bufferAndDryAir {
                in item compressedAir : CompressedAir;
                out item conditionedAir : CompressedAir;
            }

            action distributeServiceAir {
                in item conditionedAir : CompressedAir;
                out item deliveredAir : CompressedAir;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall use a trompe to transform falling water energy into compressed air by entraining atmospheric air into a descending water column, compressing the entrained air hydrostatically, separating it from the water, and delivering it to a service manifold. */

        subject plant : TrompeCompressedAirPlant;

        require constraint {
            plant.designAirDeliveryPressure >= 250000.0 [Pa];
            plant.designAirFlow >= 0.050 [m^3/s];
        }
    }

    requirement def PassiveCompressionRequirement {
        doc
        /* The system shall perform air compression without pistons, rotary compressor elements, electric motors, or combustion-driven prime movers in the compression path. */

        subject plant : TrompeCompressedAirPlant;

        require constraint {
            plant.overallCompressionEfficiency >= 0.45;
        }
    }

    requirement def WaterContinuityRequirement {
        doc
        /* The system shall return process water to the tailrace after air separation with residual entrained air below the specified limit. */

        subject separator : SeparationChamber;

        require constraint {
            separator.separationEfficiency >= 0.95;
        }
    }

    requirement def PressureProtectionRequirement {
        doc
        /* The system shall prevent the receiver and compressed-air distribution path from exceeding their maximum allowable pressure. */

        subject plant : TrompeCompressedAirPlant;

        require constraint {
            plant.receiver.maximumAllowablePressure <= 410000.0 [Pa];
            plant.controller.highPressureTrip < plant.receiver.maximumAllowablePressure;
        }
    }

    requirement def ServiceAirQualityRequirement {
        doc
        /* The system shall reduce entrained moisture before delivering compressed air to service users. */

        subject dryer : MoistureSeparator;

        require constraint {
            dryer.removalEfficiency >= 0.90;
        }
    }

    requirement def OperatingHeadRequirement {
        doc
        /* The trompe shall have sufficient hydraulic head to develop the required compressed-air pressure after hydraulic and separation losses. */

        subject plant : TrompeCompressedAirPlant;

        require constraint {
            plant.grossHead >= 28.0 [m];
            plant.designAirDeliveryPressure <= plant.downcomer.allowableSurgePressure;
        }
    }

    satisfy PrimaryFunctionRequirement by TrompeCompressedAirPlant;
    satisfy PassiveCompressionRequirement by TrompeCompressedAirPlant;
    satisfy WaterContinuityRequirement by SeparationChamber;
    satisfy PressureProtectionRequirement by TrompeCompressedAirPlant;
    satisfy ServiceAirQualityRequirement by MoistureSeparator;
    satisfy OperatingHeadRequirement by TrompeCompressedAirPlant;
}