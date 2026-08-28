package 'Drinking Straw System' {
    private import ScalarValues::*;
    
    package Definitions {
        item def Beverage {
            attribute volume : Real;
            attribute viscosity : Real;
            attribute density : Real;
            attribute temperature : Real;
        }
        
        port def LiquidPort {
            out item liquid : Beverage;
        }
        
        port def PressurePort {
            out attribute pressure : Real;
        }
        
        part def HumanUser {
            attribute maxSuctionPressure : Real;
            attribute currentSuctionPressure : Real;
            attribute isSuctionApplied : Boolean = false;
            attribute volumeConsumed : Real;
            port mouthPort : ~LiquidPort;
            port suctionPort : ~PressurePort;
            
            action def Swallow {
                in liquidIn : Beverage;
                out volumeSwallowed : Real;
            }
            
            perform action swallow : Swallow {
                in liquidIn = mouthPort.liquid;
                out volumeSwallowed = volumeConsumed;
            }
        }
        
        part def BeverageContainer {
            attribute capacity : Real;
            attribute currentVolume : Real;
            attribute ambientPressure : Real;
            port liquidPort : LiquidPort;
            item storedBeverage : Beverage;
        }
        
        part def DrinkingStraw {
            attribute length : Real;
            attribute innerDiameter : Real;
            attribute outerDiameter : Real;
            attribute material : String;
            attribute flowResistance : Real;
            attribute isBlocked : Boolean = false;
            port bottomEnd : ~LiquidPort;
            port topEnd : LiquidPort;
            
            constraint positiveResistance {
                flowResistance > 0
            }
        }
        
        action def TransferLiquid {
            in suctionPressure : Real;
            in ambientPressure : Real;
            in beverage : Beverage;
            in strawResistance : Real;
            out deliveredLiquid : Beverage;
        }
        
        part def DrinkingSystem {
            attribute isSuctionApplied : Boolean = false;
            attribute currentSuctionPressure : Real;
            attribute isBlocked : Boolean = false;
            attribute requiredSuctionPressure : Real;
            attribute ambientPressure : Real;
            
            part user : HumanUser;
            part container : BeverageContainer;
            part straw : DrinkingStraw;
            
            flow of liquid : Beverage
                from container.liquidPort.liquid to straw.bottomEnd.liquid;
            
            flow of liquid : Beverage
                from straw.topEnd.liquid to user.mouthPort.liquid;
            
            perform action drink : TransferLiquid {
                in suctionPressure = currentSuctionPressure;
                in ambientPressure = ambientPressure;
                in beverage = container.storedBeverage;
                in strawResistance = straw.flowResistance;
                out deliveredLiquid = user.mouthPort.liquid;
            }
            
            constraint pressureDifferentialExists {
                currentSuctionPressure < ambientPressure
            }
            
            exhibit state drinkingProcess {
                entry; then idle;
                state idle;
                transition from idle to priming when isSuctionApplied;
                state priming;
                transition from priming to flowing when currentSuctionPressure > requiredSuctionPressure;
                transition from priming to idle when !isSuctionApplied;
                transition from priming to blocked when isBlocked;
                state flowing;
                transition from flowing to idle when !isSuctionApplied;
                transition from flowing to blocked when isBlocked;
                state blocked;
                transition from blocked to idle when !isBlocked;
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part drinkingSystem : DrinkingSystem {
            attribute :>> requiredSuctionPressure = 5000;
            attribute :>> ambientPressure = 101325;
            attribute :>> isSuctionApplied = false;
            attribute :>> currentSuctionPressure = 0;
            attribute :>> isBlocked = false;
            
            part :>> user {
                attribute :>> maxSuctionPressure = 80000;
                attribute :>> isSuctionApplied = false;
                attribute :>> currentSuctionPressure = 0;
                attribute :>> volumeConsumed = 0;
            }
            
            part :>> container {
                attribute :>> capacity = 0.0005;
                attribute :>> currentVolume = 0.0005;
                attribute :>> ambientPressure = 101325;
                
                item :>> storedBeverage {
                    attribute :>> volume = 0.0005;
                    attribute :>> viscosity = 0.001;
                    attribute :>> density = 1000;
                    attribute :>> temperature = 293.15;
                }
            }
            
            part :>> straw {
                attribute :>> length = 0.2;
                attribute :>> innerDiameter = 0.006;
                attribute :>> outerDiameter = 0.007;
                attribute :>> material = "Polypropylene";
                attribute :>> flowResistance = 15000;
                attribute :>> isBlocked = false;
            }
        }
    }
    
    package Requirements {
        private import Definitions::*;
        private import Usages::*;
        
        requirement def TransferLiquidRequirement {
            doc
            /*
             * The system shall transfer liquid from the container to the
             * user's mouth through the drinking straw by the application of suction.
             */
            subject theSystem : DrinkingSystem;
        }
        
        requirement def PressureDifferentialRequirement {
            doc
            /*
             * The user shall create a low-pressure area at the top end of the
             * straw, producing a pressure differential relative to the ambient
             * atmospheric pressure on the liquid surface in the container,
             * sufficient to push the beverage up through the straw.
             */
            subject theSystem : DrinkingSystem;
        }
        
        requirement def OvercomeResistanceRequirement {
            doc
            /*
             * The suction pressure shall be strong enough to overcome the
             * combined resistance of the liquid weight and the straw flow
             * resistance to achieve and sustain continuous flow.
             */
            subject theSystem : DrinkingSystem;
        }
        
        requirement def BlockedStateRequirement {
            doc
            /*
             * The system shall enter a blocked state when the straw flow is
             * obstructed and shall return to idle when the obstruction is cleared.
             */
            subject theSystem : DrinkingSystem;
        }
        
        requirement def BeveragePropertyRequirement {
            doc
            /*
             * The beverage shall be characterized by its viscosity, density,
             * and temperature, which together determine the required suction
             * pressure for flow through the straw.
             */
            subject theBeverage : Beverage;
        }
        
        requirement transferLiquid : TransferLiquidRequirement;
        requirement pressureDifferential : PressureDifferentialRequirement;
        requirement overcomeResistance : OvercomeResistanceRequirement;
        requirement handleBlockedState : BlockedStateRequirement;
        requirement beverageProperties : BeveragePropertyRequirement;
    }
}
