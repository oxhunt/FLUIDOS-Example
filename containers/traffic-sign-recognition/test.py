import cv2

# Read the image in headless mode (without GUI)
image = cv2.imread("R.png", cv2.IMREAD_UNCHANGED)

# Check if the image was successfully read
if image is not None:
    # Display the image (headlessly)
    cv2.imshow("Image", image)
    cv2.waitKey(0)
    cv2.destroyAllWindows()
else:
    print("Error: Failed to read the image.")