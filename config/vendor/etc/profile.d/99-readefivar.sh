# Ensure that our EFI var injection is working by printing it on login to a shell
EFIVAR="ASCIIFun-00000000-1111-2222-3333-444444444444"
echo "Printing value injected from EFI var ${EFIVAR}"
test -f "/sys/firmware/efi/efivars/${EFIVAR}" || echo "EFI var injection does not seem to be working :("
lolcat "/sys/firmware/efi/efivars/${EFIVAR}"
echo ""
echo ""

# Print Secure Boot state
mokutil --sb-state
echo ""
