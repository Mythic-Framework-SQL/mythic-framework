PropertyInteriors = PropertyInteriors or {}

PropertyInteriors["house_nbl"] = {
    type = "house",
    price = 120000,
    info = {
        name = "Style NBL",
        description = "Description",
    },
    locations = {
        front = {
            coords = vector3(-14.69, -689.68, 184.41),
            heading = 163.768,
            polyzone = {
                center = vector3(-14.69, -689.68, 184.41),
                length = 1.0,
                width = 2.0,
                options = {
                    heading = 340,
                    --debugPoly=true,
                    minZ = 183.41,
                    maxZ = 186.21
                }
            }
        },
    },
    zone = {
        center = vector3(-19.23, -698.31, 184.45),
        length = 22.6,
        width = 20.0,
        options = {
            heading = 340,
            --debugPoly=true,
            minZ = 182.05,
            maxZ = 190.05
        }
    },
    defaultFurniture = {
        {
            id = 1,
            name = "Default Storage",
            model = "v_res_tre_storagebox",
            coords = { x =  -16.852, y = -690.670, z = 184.413 },
            heading = 207.763,
            data = {},
        },
    },
    cameras = {
        {
            name = "Living Area",
            coords = vec3(-20.26, -709.51, 187.01),
            rotation = vec3(-3.976376, 0.000000, 40.064541),
        },
        {
            name = "Bedroom",
            coords = vec3(-26.47, -694.14, 187.64),
            rotation = vec3(-19.645638, 0.000000, 14.631672),
        },
    }
}